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
	Server-Side Config discovering
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

	function nzu.ConfigExists(f,ctype)
		if ctype then return file.IsDir(configdirs[ctype]..f, "GAME") end
		return file.IsDir(configdirs.Official..f, "GAME") or file.IsDir(configdirs.Local..f, "GAME") or file.IsDir(configdirs.Workshop..f, "GAME")
	end
end

--[[-------------------------------------------------------------------------
	Clientside caching and receiving of Configs
---------------------------------------------------------------------------]]
if CLIENT then
	local hasreceivedconfigs = false
	net.Receive("nzu_configsnetworked", function(len)
		hasreceivedconfigs = net.ReadBool()
	end)

	local configs = {Official = {}, Local = {}, Workshop = {}} -- Clients cache configs and only further get networks from individual config updates
	net.Receive("nzu_saveconfig", function(len)
		local ctype = net.ReadString()
		if not configs[ctype] then configs[ctype] = {} end

		local codename = net.ReadString()
		local config = configs[ctype][codename]
		local new = false
		if not config then
			config = {Type = ctype, Codename = codename}
			configs[ctype][config.Codename] = config
			new = true
		end
		config.Name = net.ReadString()
		config.Map = net.ReadString()
		config.Authors = net.ReadString()
		config.Description = net.ReadString()
		config.WorkshopID = net.ReadString()
		if config.WorkshopID == "" then config.WorkshopID = nil end

		local numaddons = net.ReadUInt(8)
		config.RequiredAddons = {}
		if numaddons > 0 then
			for i = 1,numaddons do
				local id = net.ReadString()
				local name = net.ReadString()
				config.RequiredAddons[id] = name
			end
		end

		print("Running here")
		hook.Run("nzu_ConfigInfoUpdated", config, new) -- Call the same hook

		if net.ReadBool() then -- Currently loaded
			nzu.CurrentConfig = config
			hook.Run("nzu_CurrentConfigChanged", config)
		end

		print("Received Config networking: " ..config.Codename .." ("..config.Type..") New: "..(new and "true" or "false"))
	end)

	local function requestconfigs()
		net.Start("nzu_configsnetworked")
		net.SendToServer()
	end

	-- Replica of the SERVER structure, but loading from cache
	function nzu.GetConfig(f,ctype)
		if not hasreceivedconfigs then requestconfigs() end -- Not nil! Can be used to check
		if ctype then return configs[ctype][f] end
		return configs.Official[f] or configs.Local[f] or configs.Workshop[f]
	end
	nzu.ConfigExists = nzu.GetConfig -- Just an alias when working with cache anyway

	function nzu.GetConfigs()
		if not hasreceivedconfigs then requestconfigs() end
		return configs
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
		center:DockMargin(5,0,5,0)

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
		self.Button.DoClick = function() self:DoClick() end

		self:DockPadding(5,5,5,5)
		self.m_bDrawCorners = true
	end

	local typecolors = {
		Official = Color(255,0,0),
		Local = Color(0,0,255),
		Workshop = Color(150,0,255),
	}
	local mapinstalled,mapnotinstalled = Color(100,255,100), Color(255,100,100)
	function CONFIGPANEL:Update(config)
		--print(self, config.Name, self.Config.Name)
		if self.Config == config then
			self.Name:SetText(config.Name or "")
			self.Map:SetText(config.Codename .. " || " .. config.Map)

			local status = file.Find("maps/"..config.Map..".bsp", "GAME")[1] and true or false
			self.MapStatus:SetText(status and "Map installed" or "Map not installed")
			self.MapStatus:SetTextColor(status and mapinstalled or mapnotinstalled)

			self.Type:SetText(config.Type)
			self.Type:SetTextColor(typecolors[config.Type] or color_white)

			self.Thumbnail:SetImage("../"..configdirs[config.Type].."/"..config.Codename.."/thumb.jpg")
		end
	end

	function CONFIGPANEL:SetConfig(config)
		self.Config = config
		self:Update(config)
		hook.Add("nzu_ConfigInfoUpdated", self, self.Update) -- Auto-update ourselves whenever updates arrive to this config
	end

	function CONFIGPANEL:DoClick() end
	function CONFIGPANEL:DoRightClick() end

	function CONFIGPANEL:PerformLayout(w,h)
		self.Button:SetSize(w,h)
		self.Thumbnail:SetWide((h-10)*(16/9))
	end
	vgui.Register("nzu_ConfigPanel", CONFIGPANEL, "DPanel")

	-- FUNCTIONS FOR UPDATING AND CREATING CONFIGS (Requests)
	function nzu.RequestSaveConfig(config)
		if not nzu.IsAdmin(LocalPlayer()) then return false end
		net.Start("nzu_saveconfig") -- We don't network type: It will always overwrite the local config of this codename
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
		return true
	end

	function nzu.RequestLoadConfig(config)
		net.Start("nzu_loadconfig")
			net.WriteBool(true)
			net.WriteString(config.Codename)
			net.WriteString(config.Type)
		net.SendToServer()
	end

	function nzu.RequestUnloadConfig()
		net.Start("nzu_loadconfig")
			net.WriteBool(false)
		net.SendToServer()
	end
end