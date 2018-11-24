
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
		if file.Exists(prefix..filename, searchpath) then
			AddCSLuaFile(filename)
			include(filename)
		end
	end

	if NZU_NZOMBIES then
		local filename = extensionpath..name.."/nzombies.lua"
		if file.Exists(prefix..filename, searchpath) then
			AddCSLuaFile(filename)
			include(filename)
		end
	end

	local settings, panelfunc
	local filename = extensionpath..name.."/settings.lua"
	if file.Exists(prefix..filename, searchpath) then
		AddCSLuaFile(filename)
		settings, panelfunc = include(filename)

		if settings then
			loadingextension.Settings = {}
			for k,v in pairs(settings) do
				loadingextension.Settings[k] = v.Default
			end
		end
	end

	loaded_extensions[name] = {Extension = loadingextension, Settings = settings, Panel = panelfunc}
	loadingextension = nil

	hook.Run("nzu_ExtensionLoaded", name)
end

function nzu.GetExtension(name) return loaded_extensions[name] and loaded_extensions[name].Extension end
function nzu.GetExtensionSettings(name) return loaded_extensions[name] and loaded_extensions[name].Settings end
function nzu.IsExtensionLoaded(name) return loaded_extensions[name] and true or false end
if CLIENT then function nzu.GetExtensionPanelFunction(name) return loaded_extensions[name] and loaded_extensions[name].Panel end end

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
		if not nzu.IsAdmin(ply) then return end
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

local function netwritesetting(eid,set,tbl,val)
	net.WriteString(eid)
	net.WriteString(set)
	if tbl.NetSend then
		tbl.NetSend(val)
	elseif tbl.Type then
		writetypes[tbl.Type](val)
	end
end
local function netreadsetting(tbl)
	local val
	if tbl.NetRead then
		val = tbl.NetRead(self)
	elseif tbl.Type then
		val = net.ReadVars[tbl.Type]()
	end
	return val
end

if SERVER then
	util.AddNetworkString("nzu_extension_setting")

	local function NetworkExtensionSetting(ext, setting, settingtbl, ply)
		if settingtbl then
			net.Start("nzu_extension_setting")
				netwritesetting(ext.ID,setting,settingtbl,ext.Settings[setting])
			return ply and net.Send(ply) or net.Broadcast()
		end
	end

	function nzu.SetExtensionSetting(ext, setting, value)
		if type(ext) == "string" then ext = nzu.GetExtension(ext) end
		if not ext or not ext.Settings then return end

		local settingtbl = nzu.GetExtensionSettings(ext.ID)[setting]
		if settingtbl and settingtbl.Parse then
			value = settingtbl.Parse(value)
		end

		ext.Settings[setting] = value
		if NZU_SANDBOX then
			NetworkExtensionSetting(ext, setting, settingtbl)
		end

		hook.Run("nzu_ExtensionSettingChanged", ext.ID, setting, value)
	end

	net.Receive("nzu_extension_setting", function(len, ply)
		if not nzu.IsAdmin(ply) then
			-- Not an admin, network back the old value to correct them back
			ply:ChatPrint("You cannot change this Extension setting as you are not an admin.")

			local eid = net.ReadString()
			local setting = net.ReadString()

			local settingtbl = nzu.GetExtensionSettings(eid)[setting]
			if not settingtbl then return end

			NetworkExtensionSetting(eid, setting, settingtbl, ply) -- Back with the old value!
		return end
		
		local eid = net.ReadString()
		local setting = net.ReadString()

		local settingtbl = nzu.GetExtensionSettings(eid)[setting]
		if not settingtbl then return end

		local val = netreadsetting(settingtbl)
		nzu.SetExtensionSetting(eid, setting, val)
	end)
else
	net.Receive("nzu_extension_setting", function(len)
		local eid = net.ReadString()
		local setting = net.ReadString()
		
		-- Can't receive settings for non-existent extension :(
		local ext = nzu.GetExtension(eid)
		if not ext or not ext.Settings then return end

		-- Can't receive settings for what isn't specified as a setting :(
		local settingtbl = nzu.GetExtensionSettings(ext.ID)[setting]
		if not settingtbl then return end

		local val = netreadsetting(settingtbl)
		ext.Settings[setting] = val
		hook.Run("nzu_ExtensionSettingChanged", eid, setting, val)
	end)

	-- Request setting changes
	function nzu.RequestExtensionSetting(ext, setting, value)
		if type(ext) == "string" then ext = nzu.GetExtension(ext) end
		if not ext or not ext.Settings then return end

		local settingtbl = nzu.GetExtensionSettings(ext.ID)[setting]
		if settingtbl then
			if settingtbl.Parse then value = settingtbl.Parse(value) end

			net.Start("nzu_extension_setting")
				netwritesetting(ext.ID,setting,settingtbl,value)
			net.SendToServer()
		end
	end
end
