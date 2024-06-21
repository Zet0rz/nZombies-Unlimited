--[[-------------------------------------------------------------------------
Networking the config to Clients
How these are networked depends on the gamemode, in Sandbox (here) we share the full information, so that it can be edited
(In nZU for example, we only share the bare minimum data that will be shown on the main menu screen)
---------------------------------------------------------------------------]]
local MAX_NUM_REQUIRED_ADDONS_BITS = 8 -- A config cannot have more than 255 required addons (we can up this later if people ask for it)

local configcategories_lookup = {[0] = "Unknown", [1] = "Official", [2] = "Workshop", [3] = "Local"}
local configcategories_enum = {
	Official = 1,
	Workshop = 2,
	Local = 3,
}

local function write_config(config)
	net.WriteString(config.Codename)
	net.WriteUInt(configcategories_enum[config.Type] or 0, 2)
	if config.Format == nzu.LatestConfigFormat then
		net.WriteBool(true)
	else
		net.WriteBool(false)
		net.WriteString(config.Format)
	end
end

local function write_config_meta(config)
	net.WriteString(config.Name or "")
	net.WriteString(config.Authors or "")
	net.WriteString(config.Description or "")
	net.WriteUInt64(config.WorkshopID or 0)

	local num = config.RequiredAddons and #config.RequiredAddons or 0
	net.WriteUInt(num, MAX_NUM_REQUIRED_ADDONS_BITS)
	if num > 0 then
		for k,v in pairs(config.RequiredAddons) do
			net.WriteUInt64(v)
		end
	end
end

local function read_config_meta(tbl)
	tbl.Name = net.ReadString()
	tbl.Authors = net.ReadString()
	tbl.Description = net.ReadString()
	local workshop = net.ReadUInt64()
	tbl.WorkshopID = workshop ~= "0" and workshop or nil
	local num = net.ReadUInt(MAX_NUM_REQUIRED_ADDONS_BITS)
	if num > 0 then
		tbl.RequiredAddons = {}
		for i = 1, num do
			table.insert(tbl.RequiredAddons, net.ReadUInt64())
		end
	else
		tbl.RequiredAddons = nil -- Delete the old
	end
end


if SERVER then
	--[[-------------------------------------------------------------------------
	Utility and network strings
	---------------------------------------------------------------------------]]
	util.AddNetworkString("nzu_config_info") -- SERVER: Send config info					|| CLIENT: Request Config List
	util.AddNetworkString("nzu_config_save") -- SERVER: Network that we made a local copy	|| CLIENT: Request Config Save
	util.AddNetworkString("nzu_config_load") -- SERVER: Send current config 				|| CLIENT: Request Config Load
	
	local function read_config(no_load)
		local codename = net.ReadString()
		local ctype = configcategories_lookup[net.ReadUInt(2)]
		local format = net.ReadBool() and nzu.LatestConfigFormat or net.ReadString()
		if no_load then return codename, ctype, format end

		if nzu.CurrentConfig and codename == nzu.CurrentConfig.Codename and ctype == nzu.CurrentConfig.Type and format == nzu.CurrentConfig.Format then return nzu.CurrentConfig end
		return nzu.GetConfig(ctype, codename, format)
	end

	-- Retrieve a CRecipientFilter that networks to all players who have active config listening on
	local function get_networked_players()
		local filter = RecipientFilter()
		for k,v in pairs(player.GetAll()) do
			if v.nzu_ConfigsRequested then filter:AddPlayer(v) end
		end
		if filter:GetCount() > 0 then return filter end
	end

	--[[-------------------------------------------------------------------------
	Receiving requests for Config lists, or Config metadata
	---------------------------------------------------------------------------]]
	net.Receive("nzu_config_info", function(len, ply)
		if ply.nzu_ConfigsRequested or not nzu.HasPermission(ply, "Configs") then return end
		ply.nzu_ConfigsRequested = true

		for k,v in pairs(nzu.FindConfigs()) do
			local config = nzu.GetConfig(v)
			if config then
				print("Networking...")
				PrintTable(config)
				net.Start("nzu_config_info")
					write_config(config)
					write_config_meta(config)
				net.Send(ply)
			end
		end

		-- Also send the current config
		if nzu.CurrentConfig then
			net.Start("nzu_config_load")
				write_config(nzu.CurrentConfig)
			net.Send(ply)
		end
	end)

	--[[-------------------------------------------------------------------------
	Setting the Current Config
	---------------------------------------------------------------------------]]
	function nzu.SetCurrentConfig(config)
		-- Support providing a path instead of a Config object
		if type(config) == "string" then config = nzu.GetConfig(config) end

		-- If we actually passed a config and this config actually exists on disk (i.e. it is not new!), we try loading it before we move on
		-- If this fails, we do not continue. Note, that this will also change map, if the map doesn't match the current
		-- It will only return true once properly loaded in the actual map
		if config and nzu.ConfigExists(config.Path) and not nzu.LoadConfig(config) then return end

		-- Run hook to say we changed the config
		local old_config = nzu.CurrentConfig
		nzu.CurrentConfig = config
		hook.Run("nzu_ConfigChanged", old_config, config)

		-- Network it to all players who have active config watching up
		local filter = get_networked_players()
		if filter then
			net.Start("nzu_config_load")
				write_config(config)
			net.Send(filter)
		end
	end

	-- Receiving a client's request to load a config
	net.Receive("nzu_config_load", function(len, ply)
		if not nzu.HasPermission(ply, "Configs") then return end
		local config = read_config()
		if config then
			nzu.SetCurrentConfig(config)
		end
	end)


	--[[-------------------------------------------------------------------------
	Receiving a request to save the config
	---------------------------------------------------------------------------]]
	net.Receive("nzu_config_save", function(len, ply)
		local config = nzu.CurrentConfig
		if not config or not nzu.HasPermission(ply, "Configs") then return end
		local codename, ctype, format = read_config(true)
		if config.Codename ~= codename or config.Type ~= ctype or config.Format ~= format then return end -- We don't validate!

		local made_copy = false
		if net.ReadBool() then
			-- If we received a bool, we want to save the info
			read_config_meta(config)
			made_copy = nzu.SaveConfigMetadata()

			-- Network the changes out to everyone else
			local filter = get_networked_players()
			if filter then
				--filter:RemovePlayer(ply)
				net.Start("nzu_config_info")
					write_config(config)
					write_config_meta(config)
				net.Send(filter)
			end
		else
			-- The client wants to save the map & settings
			made_copy = nzu.SaveConfigSettings()
			nzu.SaveConfigMap()
		end

		-- If the act of saving made a copy, we network it as the new active config
		if made_copy then
			net.Start("nzu_config_save")
			net.Send(filter)
		end
	end)
end

if CLIENT then
	--[[-------------------------------------------------------------------------
	Utility
	---------------------------------------------------------------------------]]
	local config_cache = nzu.KnownConfigs
	nzu.KnownConfigs = config_cache

	local function create_or_get_config(format, ctype, codename, put)
		if not config_cache[format] then config_cache[format] = {} end
		if not config_cache[format][ctype] then config_cache[format][ctype] = {} end

		local config = config_cache[format][ctype][codename]
		if not config then
			config = put or {
				Codename = codename,
				Type = ctype,
				Format = format,
			}
			config_cache[format][ctype][codename] = config
		end
		return config
	end	
	
	local function read_config()
		local codename = net.ReadString()
		local ctype = configcategories_lookup[net.ReadUInt(2)]
		local format = net.ReadBool() and nzu.LatestConfigFormat or net.ReadString()

		-- Insert all the necessary subtables if they didn't exist
		return create_or_get_config(format, ctype, codename)
	end

	function nzu.GetKnownConfigs()
		return config_cache
	end

	--[[-------------------------------------------------------------------------
	Receiving information about Config
	---------------------------------------------------------------------------]]

	net.Receive("nzu_config_info", function()
		if not config_cache then config_cache = {} end
		local config = read_config()

		-- Assign information to the Config
		read_config_meta(config)
	end)

	--[[-------------------------------------------------------------------------
	Receiving active Config
	---------------------------------------------------------------------------]]
	net.Receive("nzu_config_load", function()
		nzu.CurrentConfig = read_config()
	end)

	--[[-------------------------------------------------------------------------
	Request the list of Configs
	---------------------------------------------------------------------------]]
	function nzu.RequestConfigList()
		if config_cache or not nzu.HasPermission(LocalPlayer(), "Configs") then return end -- Don't request a list if we either already have, or we don't have permission
		net.Start("nzu_config_info")
		net.SendToServer()
		return true
	end

	--[[-------------------------------------------------------------------------
	Request loading a Config
	---------------------------------------------------------------------------]]
	function nzu.RequestLoadConfig(config)
		if not nzu.HasPermission(LocalPlayer(), "Configs") then return end
		net.Start("nzu_config_load")
			if config then
				net.WriteBool(true)
				write_config(config)
			else
				net.WriteBool(false)
			end
		net.SendToServer()
		return true
	end

	--[[-------------------------------------------------------------------------
	Request saving Config metadata
	---------------------------------------------------------------------------]]
	function nzu.RequestSaveConfigInfo()
		local config = nzu.CurrentConfig
		if not config or not nzu.HasPermission(LocalPlayer(), "Configs") then return end
		net.Start("nzu_config_save")
			write_config(config) -- Network the config to validate to the server we know what we're saving
			net.WriteBool(true) -- Tell the server we're saving config info
			write_config_meta(config)
		net.SendToServer()
		return true
	end

	--[[-------------------------------------------------------------------------
	Request saving Config map
	---------------------------------------------------------------------------]]
	function nzu.RequestSaveConfigMap(config)
		local config = nzu.CurrentConfig
		if not config or not nzu.HasPermission(LocalPlayer(), "Configs") then return end
		net.Start("nzu_config_save")
			write_config(config) -- Network the config to validate to the server we know what we're saving
			net.WriteBool(false) -- Tell the server we're saving config map
		net.SendToServer()
		return true
	end

	--[[-------------------------------------------------------------------------
	Receive information that we made a new local copy of the active config
	---------------------------------------------------------------------------]]
	net.Receive("nzu_config_save", function()
		local config = nzu.CurrentConfig
		if not config then return end
		local new_copy = create_or_get_config(nzu.LatestConfigFormat, "Local", config.Codename)
		table.CopyFromTo(config, new_copy)
		new_copy.Format = nzu.LatestConfigFormat
		new_copy.Type = "Local"

		nzu.CurrentConfig = new_copy
	end)
end