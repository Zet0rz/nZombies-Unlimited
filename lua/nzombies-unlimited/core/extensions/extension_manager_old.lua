
if SERVER then
	util.AddNetworkString("nzu_extension_load")
	util.AddNetworkString("nzu_extension_available")
	util.AddNetworkString("nzu_extension_setting")
end

local extensions = {}
function nzu.GetExtension(id)
	return extensions[id]
end

local extensionpath = "nzombies-unlimited/extensions/"
local searchpath = "GAME"
local prefix = "lua/"

local availableextensions = {}
function nzu.RefreshExtensions()
	local _,dirs = file.Find(prefix..extensionpath.."*", searchpath)
	for k,v in pairs(dirs) do
		local str = file.Read(prefix..extensionpath..v.."/extension.json", searchpath)
		if str then
			local tbl = util.JSONToTable(str)
			if tbl then
				if not availableextensions[v] then
					availableextensions[v] = {Loaded = false}
					if SERVER then
						-- Server will notify everyone of its availability
						net.Start("nzu_extension_available")
							net.WriteString(v)
							net.WriteBool(true)
						net.Broadcast()
					end
				end
				availableextensions[v].Details = tbl

				-- Clients need to receive word from server that this extension is available or it will not be available
				if CLIENT then availableextensions[v].Available = availableextensions[v].Available or false end
				return
			end
		end
		if availableextensions[v] then availableextensions[v] = nil end
	end
end
if CLIENT then
	net.Receive("nzu_extension_available", function()
		local id = net.ReadString()
		if not availableextensions[id] then availableextensions[id] = {} end
		availableextensions[id].Available = net.ReadBool()
	end)
end

nzu.RefreshExtensions()

function nzu.GetExtensionDetails(id)
	return availableextensions[id] and availableextensions[id].Details
end
function nzu.IsExtensionLoaded(id)
	return availableextensions[id] and availableextensions[id].Loaded
end
function nzu.GetExtensionList() return availableextensions end

local loadluafiles
loadluafiles = function(dir)
	local f,d = file.Find(prefix..dir.."*", searchpath)
	for k,v in pairs(f) do
		local f2 = dir..v
		local sep = string.sub(v,1,3)
		if sep == "cl_" then
			if SERVER then AddCSLuaFile(f2) else include(f2) end
		elseif sep == "sv_" then
			if SERVER then include(f2) end
		else
			AddCSLuaFile(f2)
			include(f2)
		end
	end

	for k,v in pairs(d) do
		loadluafiles(dir..v.."/")
	end
end

local EXTENSION = {}
EXTENSION.__index = EXTENSION

-- Handle Settings using same structure as LOGIC tables, same networking too
local writetypes = {
	[TYPE_STRING]		= function ( v )	net.WriteString( v )		end,
	[TYPE_NUMBER]		= function ( v )	net.WriteDouble( v )		end,
	[TYPE_TABLE]		= function ( v )	net.WriteTable( v )			end,
	[TYPE_BOOL]			= function ( v )	net.WriteBool( v )			end,
	[TYPE_ENTITY]		= function ( v )	net.WriteEntity( v )		end,
	[TYPE_VECTOR]		= function ( v )	net.WriteVector( v )		end,
	[TYPE_ANGLE]		= function ( v )	net.WriteAngle( v )			end,
	[TYPE_MATRIX]		= function ( v )	net.WriteMatrix( v )		end,
	[TYPE_COLOR]		= function ( v )	net.WriteColor( v )			end,
}
function EXTENSION:NetWriteSetting(setting, val)
	local settingtbl = self.Settings[setting]
	net.WriteString(setting)
	if settingtbl.NetSend then
		settingtbl.NetSend(self, val)
	elseif settingtbl.Type then
		writetypes[settingtbl.Type](val)
	end
end

function EXTENSION:NetReadSetting()
	local setting = net.ReadString()
	local settingtbl = self.Settings[setting]
	if settingtbl.NetRead then
		val = settingtbl.NetRead(self)
	elseif settingtbl.Type then
		val = net.ReadVars[settingtbl.Type]()
	end

	return setting, val
end

function EXTENSION:GetSetting(key)
	return self.m_tExtensionSettings[key]
end

function EXTENSION:GetSettingsList()
	return self.Settings
end

local loadingextension
function nzu.Extension() return loadingextension end

if SERVER then
	
	function EXTENSION:SetSetting(key)
		if not self.Settings or not self.Settings[setting] then return end
		local settingtbl = self.Settings[setting]
		if settingtbl.Parse then val = settingtbl.Parse(self, val) end

		self.m_tExtensionSettings[setting] = val

		if NZU_SANDBOX then
			net.Start("nzu_extension_setting")
				net.WriteString(self.ID)
				self:NetWriteSetting(setting, val)
			net.Broadcast()
		end
	end

	function nzu.LoadExtension(id)
		if not availableextensions[id] then print("Could not load Extension '"..id.."'. Maybe try nzu.RefreshExtensions()?") return end

		loadingextension = setmetatable({}, EXTENSION)
		loadluafiles(extensionpath..id)

		if loadingextension.Settings then
			loadingextension.m_tExtensionSettings = {}
			for k,v in pairs(loadingextension.Settings) do
				loadingextension.m_tExtensionSettings[k] = v.Default
			end
		end
		loadingextension.ID = id
		extensions[id] = loadingextension

		availableextensions[id].Loaded = true
		net.Start("nzu_extension_load")
			net.WriteString(id)
		net.Broadcast()

		loadingextension = nil
		hook.Run("nzu_ExtensionLoaded", id)
	end

	hook.Add("PlayerInitialSpawn", "nzu_Extension_FullSync", function(ply)
		for k,v in pairs(availableextensions) do
			net.Start("nzu_extension_available")
				net.WriteString(k)
				net.WriteBool(true)
			net.Send(ply)

			if v.Loaded then
				net.Start("nzu_extension_load")
					net.WriteString(k)
				net.Send(ply)
			end
		end
	end)

	net.Receive("nzu_extension_setting", function(len, ply)
		if nzu.IsAdmin(ply) then
			local id = net.ReadString()
			local extension = extensions[id]
			if extension and extension.Settings then
				for k,v in pairs(extension.Settings) do
					net.Start("nzu_extension_setting")
						net.WriteString(id)
						extension:NetWriteSetting(k, extension:GetSetting(k))
					net.Send(ply)
				end
			end
		end
	end)

	net.Receive("nzu_extension_load", function(len, ply)
		if nzu.IsAdmin(ply) then
			local id = net.ReadString()
			local bool = net.ReadBool()
			if availableextensions[id] and availableextensions[id].Loaded ~= bool then
				nzu.LoadExtension(id)
			end
		end
	end)
else
	net.Receive("nzu_extension_load", function()
		local id = net.ReadString()
		loadingextension = setmetatable({}, EXTENSION)
		loadluafiles(extensionpath..id)

		if extension.Settings then
			extension.m_tExtensionSettings = {}
			for k,v in pairs(extension.Settings) do
				extension.m_tExtensionSettings[k] = v.Default
			end
		end
		extension.ID = id
		extensions[id] = extension

		if not availableextensions[id] then availableextensions[id] = {} end
		availableextensions[id].Loaded = true

		loadingextension = nil
		hook.Run("nzu_ExtensionLoaded", id)
	end)

	net.Receive("nzu_extension_setting", function()
		local id = net.ReadString()
		local extension = extensions[id]
		if extension and extension.m_tExtensionSettings then
			local setting, val = extension:NetReadSetting()
			extension.m_tExtensionSettings[setting] = val
		end
	end)

	-- Internal function to request settings if they were not previously networked
	-- Only available to admins
	function EXTENSION:RequestSettings()
		if nzu.IsAdmin(LocalPlayer()) then
			net.Start("nzu_extension_setting")
				net.WriteString(self.ID)
			net.SendToServer()
		end
	end
end