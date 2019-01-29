-- File containing loading and networking of configs
--[[ CONFIG STRUCTURE
	Name = Pretty/Print name
	Codename = Folder name (has to be sanitised, cannot conflict, ID of a config)
	Type = "Official", "Local", or "Workshop" (or "Unknown")
	Path = Full filepath to directory, relative to searchpath "GAME"
	Map = Name of map played on
	Authors = Single string of author names
	Description = Single long string providing a short description of the config
	WorkshopID = ID of Workshop addon (if set)

	Extensions = {
		[ExtensionID] = {
			[setting] = value
		}
	}
	^ Also determines what extensions are enabled for this config

	RequiredAddons = {
		[ID] = Addon name,
		...
	}
	^ Lists all workshop addons required by this config
]]

-- Making this shared. It has little meaning clientside, but could be used to determine what configs the client may have locally saved
function nzu.GetConfigFromFolder(path, s)
	if file.IsDir(path, s) then
		local codename = string.match(path, ".+/(.+)")
		if not codename then
			print("nzu_saveload: Could not get config codename from path: "..path)
		return end

		local worked, info = pcall(util.JSONToTable, file.Read(path.."/info.txt", s))
		if not worked then
			print("nzu_saveload: Malformed info.txt from config '"..codename.."':\n"..info)
			-- This should return nothing! It follows that the game also can't determine the map this config is played on!
		return end

		if not info.Map then
			print("nzu_saveload: No map found for config '"..codename.."'")
		return end

		local config = {}
		config.Codename = codename
		config.Map = info.Map
		config.Name = info.Name or codename
		config.Authors = info.Authors
		config.Description = info.Description
		config.WorkshopID = info.WorkshopID
		config.Extensions = info.Extensions
		config.RequiredAddons = info.RequiredAddons

		config.Path = (s == "LUA" and "lua/" or s == "DATA" and "data/" or "")..path

		if config.Path == "gamemodes/nzombies-unlimited/officialconfigs/"..codename then
			config.Type = "Official"
			--config.Path = path
		elseif config.Path == "lua/nzombies-unlimited/workshopconfigs/"..codename then -- Replace when workshop config integration
			config.Type = "Workshop"
			--config.Path = "lua/"..path
		elseif config.Path == "data/nzombies-unlimited/localconfigs/"..codename then
			config.Type = "Local"
			--config.Path = "data/"..path
		else
			config.Type = "Unknown"
			--config.Path = path
		end

		return config
	end
end

--[[-------------------------------------------------------------------------
	Server-Side config discovering and networking
---------------------------------------------------------------------------]]
if SERVER then
	function nzu.GetOfficialConfig(f)
		return nzu.GetConfigFromFolder("gamemodes/nzombies-unlimited/officialconfigs/"..f, "GAME")
	end
	function nzu.GetLocalConfig(f)
		return nzu.GetConfigFromFolder("nzombies-unlimited/localconfigs/"..f, "DATA")
	end
	function nzu.GetWorkshopConfig(f)
		return nzu.GetConfigFromFolder("nzombies-unlimited/workshopconfigs/"..f, "LUA")
	end

	function nzu.GetConfig(f)
		-- Determines an order if configs should have the same name
		return nzu.GetOfficialConfig(f) or nzu.GetLocalConfig(f) or nzu.GetWorkshopConfig(f)
	end

	function nzu.GetConfigs()
		local configs = {Official = {}, Local = {}, Workshop = {}}

		-- Official configs
		local _,dirs = file.Find("gamemodes/nzombies-unlimited/officialconfigs/*", "GAME")
		for k,v in pairs(dirs) do
			local config = nzu.GetOfficialConfig(v)
			if config then configs.Official[config.Codename] = config end
		end

		-- Local configs
		local _,dirs = file.Find("nzombies-unlimited/localconfigs/*", "DATA")
		for k,v in pairs(dirs) do
			local config = nzu.GetLocalConfig(v)
			if config then configs.Local[config.Codename] = config end
		end

		-- Workshop configs
		local _,dirs = file.Find("nzombies-unlimited/workshopconfigs/*", "LUA")
		for k,v in pairs(dirs) do
			local config = nzu.GetWorkshopConfig(v)
			if config then configs.Workshop[config.Codename] = config end
		end

		return configs
	end

	util.AddNetworkString("nzu_configs")
	local function networkconfig(config, ply)
		net.Start("nzu_configs")
			net.WriteString(config.Type)
			net.WriteString(config.Codename)
			net.WriteString(config.Name)
			net.WriteString(config.Map)
			net.WriteString(config.Authors or "")
			net.WriteString(config.Description or "")
			net.WriteString(config.WorkshopID or "")

			-- Send list of required addons
			local num = table.Count(config.RequiredAddons)
			net.WriteUInt(num, 8) -- I don't expect more than 255 addons for a simple config
			for k,v in pairs(config.RequiredAddons) do
				net.WriteString(k)
				net.WriteString(v)
			end

			-- Extensions and Path need not be networked, only server needs to know that
		net.Send(ply)
	end

	-- Client requesting config list
	net.Receive("nzu_configs", function(len, ply)
		if nzu.IsAdmin(ply) then -- Only admins can access config lists
			ply.nzu_ConfigsRequested = true -- From now on, network to this player whenever a config is saved/updated

			for k,v in pairs(nzu.GetConfigs()) do
				for k2,v2 in pairs(v) do
					networkconfig(v2, ply)
				end
			end
		end
	end)

	hook.Add("nzu_ConfigSaved", "nzu_NetworkUpdatedConfigs", function(config)
		local plys = {}
		for k,v in pairs(player.GetAll()) do
			if nzu.IsAdmin(ply) and ply.nzu_ConfigsRequested then
				table.insert(plys, v)
			end
		end
		networkconfig(config, plys) -- Network this updated config to all players
	end)
end

--[[-------------------------------------------------------------------------
	Clientside caching and receiving of configs
---------------------------------------------------------------------------]]
if CLIENT then
	local hasreceivedconfigs = false
	local configs = {} -- Clients cache configs and only further get networks from individual config updates
	net.Receive("nzu_configs", function(len)
		local ctype = net.ReadString()
		if not configs[ctype] then configs[ctype] = {} end

		local config = {Type = ctype}
		config.Codename = net.ReadString()
		config.Name = net.ReadString()
		config.Map = net.ReadString()
		config.Authors = net.ReadString()
		config.Description = net.ReadString()
		config.WorkshopID = net.ReadString()
		if config.WorkshopID == "" then config.WorkshopID = nil end

		local numaddons = net.ReadUInt(8)
		if numaddons > 0 then
			config.RequiredAddons = {}
			for i = 1,numaddons do
				local id = net.ReadString()
				local name = net.ReadString()
				config.RequiredAddons[id] = name
			end
		end

		configs[ctype][config.Codename] = config
		hasreceivedconfigs = true -- Now we won't request the server again (the rest will come through updates)

		hook.Run("nzu_ConfigSaved", config) -- Call the same hook
	end)

	local function requestconfigs()
		net.Start("nzu_configs")
		net.SendToServer()
	end

	-- Replica of the SERVER structure, but loading from cache
	function nzu.GetOfficialConfig(f)
		if not hasreceivedconfigs then requestconfigs() return false end
		return configs.Official and configs.Official[f]
	end
	function nzu.GetLocalConfig(f)
		if not hasreceivedconfigs then requestconfigs() return false end
		return configs.Local and configs.Local[f]
	end
	function nzu.GetWorkshopConfig(f)
		if not hasreceivedconfigs then requestconfigs() return false end
		return configs.Workshop and configs.Workshop[f]
	end

	function nzu.GetConfig(f)
		-- Determines an order if configs should have the same name
		if not hasreceivedconfigs then requestconfigs() return false end
		return nzu.GetOfficialConfig(f) or nzu.GetLocalConfig(f) or nzu.GetWorkshopConfig(f)
	end

	function nzu.GetConfigs()
		if not hasreceivedconfigs then requestconfigs() return false end
		return configs
	end
end