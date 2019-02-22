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
		[Number] = {
			ID = Extension Name,
			Settings = {
				["Setting"] = value
			}
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
function nzu.GetConfigDir(ctype) return configdirs[ctype] end
function nzu.GetConfigThumbnail(config)
	return "../"..configdirs[config.Type]..config.Codename.."/thumb.jpg"
end

-- Making this shared. It has little meaning clientside, but could be used to determine what configs the client may have locally saved
function nzu.GetConfigFromFolder(path, s)
	local s = s or "GAME"
	if file.IsDir(path, s) then
		local codename = string.match(path, ".+/(.+)")
		if not codename then
			print("nzu_saveload: Could not get config codename from path: "..path)
		return end

		local worked, info = pcall(util.JSONToTable, file.Read(path.."/info.txt", s))
		if not worked or not info then
			print("nzu_saveload: Malformed info.txt from config '"..codename.."':\n", info or "Unable to parse any table.")
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
		config.Extensions = settings
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
		hook.Run("nzu_ConfigInfoSaved", config, new) -- Call the same hook

		if net.ReadBool() then -- Currently loaded
			nzu.CurrentConfig = config
			hook.Run("nzu_ConfigLoaded", config)
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
		self.Type:SetText("")

		self.MapStatus = status:Add("DLabel")
		self.MapStatus:Dock(BOTTOM)
		self.MapStatus:SetContentAlignment(9)
		self.MapStatus:SetText("")

		local center = self:Add("Panel")
		center:Dock(FILL)
		center:DockMargin(5,0,5,0)

		self.Name = center:Add("DLabel")
		self.Name:SetFont("Trebuchet24")
		self.Name:Dock(FILL)
		self.Name:SetContentAlignment(1)
		self.Name:SetText("No Config loaded")

		self.Map = center:Add("DLabel")
		self.Map:Dock(BOTTOM)
		self.Map:SetContentAlignment(7)
		self.Map:DockMargin(0,0,0,-5)
		self.Map:SetText("")

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

			self.Thumbnail:SetImage(nzu.GetConfigThumbnail(config))
		end
	end

	function CONFIGPANEL:SetConfig(config)
		self.Config = config
		self:Update(config)
		timer.Simple(0, function() hook.Add("nzu_ConfigInfoSaved", self, self.Update) end) -- Auto-update ourselves whenever updates arrive to this config
	end

	function CONFIGPANEL:DoClick() end
	function CONFIGPANEL:DoRightClick() end

	function CONFIGPANEL:PerformLayout(w,h)
		self.Button:SetSize(w,h)
		self.Thumbnail:SetWide((h-10)*(16/9))
	end

	local sortorder = {
		Official = 1,
		Local = 2,
		Workshop = 3
	}
	function CONFIGPANEL:Sort()
		if self.Config then
			self:SetZPos((self.Config.Map == game.GetMap() and 0 or 5) + (sortorder[self.Config.Type] or 0))
		else
			self:SetZPos(-1)
		end
	end
	vgui.Register("nzu_ConfigPanel", CONFIGPANEL, "DPanel")

	-- FUNCTIONS FOR UPDATING AND CREATING CONFIGS (Requests)
	function nzu.RequestLoadConfig(config)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_loadconfig")
			net.WriteBool(true)
			net.WriteString(config.Codename)
			net.WriteString(config.Type)
			net.WriteBool(false)
		net.SendToServer()
	end

	function nzu.RequestUnloadConfig()
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_loadconfig")
			net.WriteBool(false)
		net.SendToServer()
	end

	if NZU_SANDBOX then -- SAVING ONLY IN SANDBOX
		function nzu.RequestSaveConfig(config)
			if not nzu.IsAdmin(LocalPlayer()) then return end
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

				net.WriteBool(true) -- Save the entire map!
			net.SendToServer()
		end

		function nzu.RequestSaveConfigInfo(config)
			if not nzu.IsAdmin(LocalPlayer()) then return end
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

				net.WriteBool(false) -- Only save settings and info
			net.SendToServer()
			print("Networked to server")
			PrintTable(config)
		end

		function nzu.RequestDeleteConfig(config)
			if not nzu.IsAdmin(LocalPlayer()) then return end
			net.Start("nzu_deleteconfig")
				net.WriteString(config.Codename)
			net.SendToServer()
		end

		net.Receive("nzu_deleteconfig", function(len)
			local ctype = net.ReadString()
			if not configs[ctype] then return end

			local codename = net.ReadString()
			local config = configs[ctype][codename]
			configs[ctype][codename] = nil
			hook.Run("nzu_ConfigDeleted", config)

			print("Received Config deletion: " ..codename .." ("..ctype..")")
		end)		
	end

	-- Receive missing addons list
	net.Receive("nzu_loadconfig", function(len)
		local listentryheight = 25
		local maxheight = 300

		local codename = net.ReadString()
		local ctype = net.ReadString()

		local t = {}
		local num = net.ReadUInt(8)
		for i = 1,num do
			local k = net.ReadString()
			t[k] = net.ReadString()
		end

		-- Make the popup
		local f = vgui.Create("DFrame")
		f:SetSkin("nZombies Unlimited")
		f:SetTitle("Missing Addons ["..num.."]")
		f:SetSize(400, 180 + math.Min(listentryheight * num, maxheight))
		f:ShowCloseButton(true)
		f:SetBackgroundBlur(true)

		local l = f:Add("DLabel")
		l:SetText("This Config requires Addons that the server does not have installed or enabled.")
		l:Dock(TOP)
		l:SetTextColor(Color(255,100,100))
		l:SetContentAlignment(5)
		l:DockMargin(0,0,0,5)

		local l2 = f:Add("DLabel")
		l2:SetText("Go through the list and ensure they are enabled.")
		l2:Dock(TOP)
		l2:SetContentAlignment(5)
		l2:DockMargin(0,0,0,-5)

		local l3 = f:Add("DLabel")
		l3:SetText("Click 'Load anyway' to continue loading the Config.")
		l3:Dock(TOP)
		l3:SetContentAlignment(5)

		local l4 = f:Add("DLabel")
		l4:SetText("Click an entry to open it on Steam Workshop.")
		l4:Dock(TOP)
		l4:SetContentAlignment(5)
		l4:DockMargin(0,10,0,0)

		local buttonarea = f:Add("Panel")
		buttonarea:Dock(BOTTOM)
		buttonarea:SetTall(30)
		buttonarea:DockPadding(10,0,10,0)

		local load = buttonarea:Add("DButton")
		load:Dock(LEFT)
		load:SetWide(175)
		load:SetText("Load anyway")
		load.DoClick = function()
			net.Start("nzu_loadconfig")
				net.WriteBool(true)
				net.WriteString(codename)
				net.WriteString(ctype)
				net.WriteBool(true) -- This bool means ignore the addon list
			net.SendToServer()

			f:Close()
		end
		local cancel = buttonarea:Add("DButton")
		cancel:Dock(RIGHT)
		cancel:SetWide(175)
		cancel:SetText("Cancel")
		cancel.DoClick = function() f:Close() end

		-- Fill the addon list
		local scroll = f:Add("DScrollPanel")
		scroll:Dock(FILL)
		scroll:DockMargin(5,5,5,5)
		local dlist = scroll:Add("DListLayout")
		dlist:Dock(FILL)
		for k,v in pairs(t) do
			local p = dlist:Add("DButton")
			p:SetTall(listentryheight)
			p:Dock(TOP)
			p:SetText(v)
			p.DoClick = function()
				steamworks.ViewFile(k)
			end
			p:DockMargin(0,0,0,1)
		end

		f:Center()
		f:MakePopup()
		f:DoModal()

		print("Received Config deletion: " ..codename .." ("..ctype..")")
	end)
end