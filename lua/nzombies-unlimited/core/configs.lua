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

	Settings = {
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

local configdirs = {
	Official = "gamemodes/nzombies-unlimited/officialconfigs/",
	Workshop = "lua/nzombies-unlimited/workshopconfigs/",
	Local = "data/nzombies-unlimited/localconfigs/",
}

-- Making this shared. It has little meaning clientside, but could be used to determine what configs the client may have locally saved
function nzu.GetConfigFromFolder(path, s)
	local s = s or "GAME"
	if file.IsDir(path, s) then
		local codename = string.match(path, ".+/(.+)")
		if not codename then
			print("nzu_saveload: Could not get config codename from path: "..path)
		return end

		local worked, info = pcall(util.KeyValuesToTable, file.Read(path.."/info.txt", s))
		if not worked then
			print("nzu_saveload: Malformed info.txt from config '"..codename.."':\n"..info)
			-- This should return nothing! It follows that the game also can't determine the map this config is played on!
		return end

		if not info.map then
			print("nzu_saveload: No map found for config '"..codename.."'")
		return end

		local worked2, settings = pcall(util.JSONToTable, file.Read(path.."/settings.txt", s))
		if not worked2 then
			print("nzu_saveload: Malformed settings.txt from config '"..codename.."':\n"..settings)
			-- This should return nothing! It follows that the game also can't determine what extensions to enable
		return end

		local config = {}
		config.Codename = codename
		config.Map = info.map
		config.Name = info.name or codename
		config.Authors = info.authors
		config.Description = info.description
		config.WorkshopID = info.workshopid
		config.Settings = settings
		config.RequiredAddons = info.requiredaddons

		config.Path = (s == "LUA" and "lua/" or s == "DATA" and "data/" or "")..path
		for k,v in pairs(configdirs) do
			if config.Path == v..codename then
				config.Type = k
				break
			end
		end
		if not config.Type then config.Type = "Unknown" end

		return config
	end
end

--[[-------------------------------------------------------------------------
	Server-Side config discovering and networking
---------------------------------------------------------------------------]]
if SERVER then
	function nzu.GetConfig(f, ctype)
		-- Determines an order if configs should have the same name
		if ctype then return nzu.GetConfigFromFolder(configdirs[ctype]..f) end
		return nzu.GetConfigFromFolder(configdirs.Official..f) or nzu.GetConfigFromFolder(configdirs.Local..f) or nzu.GetConfigFromFolder(configdirs.Workshop..f)
	end

	function nzu.GetConfigs()
		local configs = {}
		for k,v in pairs(configdirs) do
			configs[k] = {}
			local _,dirs = file.Find(v.."*", "GAME")
			for k2,v2 in pairs(dirs) do
				local config = nzu.GetConfig(v2,k)
				if config then configs[k][config.Codename] = config end
			end
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

		hook.Run("nzu_ConfigInfoUpdated", config) -- Call the same hook
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

	function nzu.ConfigExists(f,ctype)
		if ctype then return file.IsDir(configdirs[ctype]..f) end
		return file.IsDir(configdirs.Official..f) or file.IsDir(configdirs.Local..f) or file.IsDir(configdirs.Workshop..f)
	end

	-- CONFIG PANEL
	local CONFIGPANEL = {}
	local emptyfunc = function() end
	function CONFIGPANEL:Init()
		self.Thumbnail = self:Add("DImage")
		self.Thumbnail:Dock(LEFT)

		local status = self:Add("Panel")
		status:Dock(RIGHT)

		self.Type = status:Add("DLabel")
		self.Type:Dock(TOP)
		self.Type:SetContentAlignment(3)

		self.MapStatus = status:Add("DLabel")
		self.MapStatus:Dock(BOTTOM)
		self.MapStatus:SetContentAlignment(9)

		local center = self:Add("Panel")
		center:Dock(FILL)

		self.Name = center:Add("DLabel")
		self.Name:SetFont("Trebuchet24")
		self.Name:Dock(FILL)
		self.Name:SetContentAlignment(1)

		self.Map = center:Add("DLabel")
		self.Map:Dock(BOTTOM)
		self.Map:SetContentAlignment(7)
		self.Map:DockMargin(0,0,0,-5)

		self.Button = self:Add("DButton")
		self.Button:SetText("")
		self.Button:SetSize(self:GetSize())
		self.Button.Paint = emptyfunc

		self:DockPadding(5,5,5,5)
	end

	local typecolors = {
		Official = Color(255,0,0),
		Local = Color(0,0,255),
		Workshop = Color(150,0,255),
	}
	local mapinstalled,mapnotinstalled = Color(100,255,100), Color(255,100,100)

	function CONFIGPANEL:SetConfig(config)
		self.Config = config
		self.Name:SetText(config.Name)
		self.Map:SetText(config.Codename .. " || " .. config.Map)

		local status = file.Find("maps/"..config.Map..".bsp", "GAME")[1] and true or false
		self.MapStatus:SetText(status and "Map installed" or "Map not installed")
		self.MapStatus:SetTextColor(status and mapinstalled or mapnotinstalled)

		self.Type:SetText(config.Type)
		self.Type:SetTextColor(typecolors[config.Type] or color_white)

		--self.Thumbnail:SetImage("../"..config.Path.."/thumb.jpg\n.png")
	end

	function CONFIGPANEL:DoClick() end
	function CONFIGPANEL:DoRightClick() end

	function CONFIGPANEL:PerformLayout(w,h)
		self.Button:SetSize(w,h)
		self.Thumbnail:SetWide((h-10)*(16/9))
	end
	vgui.Register("nzu_ConfigPanel", CONFIGPANEL, "DPanel")

	-- FUNCTIONS FOR UPDATING AND CREATING CONFIGS (Requests)
	local function requestconfig(config)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_createconfig") -- We don't network type: It will always overwrite the local config of this codename
			net.WriteString(config.Codename)
			net.WriteString(config.Name)
			net.WriteString(config.Authors or "")
			net.WriteString(config.Description or "")
			net.WriteString(config.WorkshopID or "")

			local num = table.Count(config.RequiredAddons)
			net.WriteUInt(num, 8) -- I don't expect more than 255 addons for a simple config
			for k,v in pairs(config.RequiredAddons) do
				net.WriteString(k)
				net.WriteString(v)
			end
		net.SendToServer()
	end
end

if SERVER then
	-- Receiving client requests
	net.Receive("nzu_createconfig", function(len, ply)
		if not nzu.IsAdmin(ply) then return end -- Of course servers need to check too!

		local codename = net.ReadString()
		if nzu.ConfigExists(codename, "Local") and nzu.CurrentConfig.Codename ~= codename then
			print("nzu_saveload: Client attempted to save to an existing config without it being loaded first.", ply, codename)
		return end

		local config = {}
		config.Codename = codename
		config.Type = "Local" 
		config.Name = net.ReadString()
		config.Map = game.GetMap()
		config.Authors = net.ReadString()
		config.Description = net.ReadString()

		local numaddons = net.ReadUInt(8)
		if numaddons > 0 then
			config.RequiredAddons = {}
			for i = 1,numaddons do
				local id = net.ReadString()
				local name = net.ReadString()
				config.RequiredAddons[id] = name
			end
		end

		-- If we happened to have an Official or Workshop loaded config by this same name,
		-- then this will result in a local copy saved
		-- We need to load this local copy from now on but without reloading everything

	end)
end