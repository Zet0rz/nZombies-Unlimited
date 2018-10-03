
local extensionpath = "nzombies-unlimited/extensions/"
local searchpath = "GAME"
local prefix = "lua/"

function nzu.IsExtensionInstalled(name)
	return file.Exists(prefix..extensionpath..name.."/extension.json", searchpath)
end

function nzu.GetExtensionDetails(name)
	local str = file.Read(prefix..extensionpath..name.."/extension.json", searchpath)
	if str then
		return util.JSONToTable(str)
	end
end

local loaded_extensions = {}
function nzu.GetInstalledExtensionList()
	local tbl = {}

	for k,v in pairs(loaded_extensions) do
		table.insert(tbl, k)
	end

	local _,dirs = file.Find(prefix..extensionpath.."*", searchpath)
	for k,v in pairs(dirs) do
		if not loaded_extensions[v] and nzu.IsExtensionInstalled(v) then
			table.insert(tbl, v)
		end
	end
	return tbl
end

local loadingextension
function nzu.Extension() return loadingextension end
local function loadextension(name)
	loadingextension = {ID = name}

	if NZU_SANDBOX then
		local filename = extensionpath..name.."/sandbox.lua"
		if file.Exists(prefix..filename) then
			AddCSLuaFile(filename)
			include(filename)
		end
	end

	if NZU_NZOMBIES then
		local filename = extensionpath..name.."/nzombies.lua"
		if file.Exists(prefix..filename) then
			AddCSLuaFile(filename)
			include(filename)
		end
	end

	local settings
	local filename = extensionpath..name.."/settings.lua"
	if file.Exists(prefix..filename) then
		AddCSLuaFile(filename)
		settings = include(filename)

		if settings then
			loadingextension.Settings = {}
			for k,v in pairs(settings) do
				loadingextension.Settings[k] = v.Default
			end
		end
	end

	loaded_extensions[name] = {Extension = loadingextension, Settings = settings}
	loadingextension = nil

	hook.Run("nzu_ExtensionLoaded", name)
end

function nzu.GetExtension(name) return loaded_extensions[name] and loaded_extensions[name].Extension end
function nzu.GetExtensionSettings(name) return loaded_extensions[name] and loaded_extensions[name].Settings end

--[[-------------------------------------------------------------------------
Loading Extensions
---------------------------------------------------------------------------]]
if SERVER then
	util.AddNetworkString("nzu_extension_load")
	function nzu.LoadExtension(name, force)
		if not force then
			local details = nzu.GetExtensionDetails(name)
			if not details then return false end
			if details.Prerequisites then
				for k,v in pairs(details.Prerequisites) do
					if not loaded_extensions[v] then return false end
				end
			end
		end

		loadextension(name)

		net.Start("nzu_extension_load")
			net.WriteString(name)
			net.WriteBool(true)
		net.Broadcast()
	end

	net.Receive("nzu_extension_load", function(len, ply)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		local name = net.ReadString()
		if net.ReadBool() then
			nzu.LoadExtension(name)
		end
	end)

	hook.Add("PlayerInitialSpawn", "nzu_ExtensionLoad", function(ply)
		for k,v in pairs(loaded_extensions) do
			net.Start("nzu_extension_load")
				net.WriteString(k)
				net.WriteBool(true)
			net.Send(ply)
		end
	end)
else
	function nzu.LoadExtension(name)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_extension_load")
			net.WriteString(name)
			net.WriteBool(true)
		net.SendToServer()
	end

	net.Receive("nzu_extension_load", function()
		local name = net.ReadString()
		if net.ReadBool() then
			loadextension(name)
		elseif loaded_extensions[name] then
			if loaded_extensions[name].Extension.Unload then loaded_extensions[name].Extension:Unload() end
			loaded_extensions[name] = nil
		end
	end)
end

--[[-------------------------------------------------------------------------
Networking Settings
---------------------------------------------------------------------------]]
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
if SERVER then
	util.AddNetworkString("nzu_extension_setting")
	function nzu.SetExtensionSettings(ext, setting, value)
		if type(ext) == "string" then ext = nzu.GetExtension(ext) end
		if not ext or not ext.Settings then return end

		ext.Settings[setting] = value
		if NZU_SANDBOX then
			local settingtbl = nzu.GetExtensionSettings(ext.ID)[setting]
			if settingtbl then
				net.Start("nzu_extension_settings")
					net.WriteString(ext.ID)
					net.WriteString(setting)
					if settingtbl.NetSend then
						settingtbl.NetSend(self, val)
					elseif settingtbl.Type then
						writetypes[settingtbl.Type](val)
					end
				net.Broadcast()
			end
		end
	end

	net.Receive("nzu_extension_setting", function(len, ply)
		if not nzu.IsAdmin(ply) then return end
		
	end)
else

end
