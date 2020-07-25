-- Extensions. A code object that can contain functions and values local to that extension.
-- It is ID-based and may contain a special "Settings" field. This field lets the gamemode know how to parse and network values
-- when they are changed through the Extension's given "SetSetting" function.
nzu.Extensions = {}

function nzu.GetExtension(name) return nzu.Extension[name] end
function nzu.IsExtensionLoaded(name) return nzu.Extension[name] and true or false end


--[[-------------------------------------------------------------------------
Networking & Setting Types
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

-- Adding our own custom TYPEs
local customtypes = {}
function nzu.AddExtensionSettingType(type, tbl)
	tbl.__index = tbl

	-- A bit of cleanup
	if SERVER then
		tbl.Panel = nil
	end

	customtypes[type] = tbl
end
function nzu.GetExtensionSettingType(type)
	return customtypes[type]
end

local function netwritesetting(tbl,set,val)
	net.WriteString(set)
	if tbl.NetWrite then
		tbl.NetWrite(val)
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

AddCSLuaFile("extension_setting_types.lua")
include("extension_setting_types.lua")




--[[-------------------------------------------------------------------------
Extension:SetSetting(key, val) function
---------------------------------------------------------------------------]]
local function dochangesetting(extension, key, val)
	local t = extension.Settings and extension.Settings[key]
	if t then
		local old = extension[key]
		local t = extension.Settings[key]

		if t.Parse then val = t:Parse(val) end

		extension[key] = val
		if t.Notify then t:Notify(extension, key, old, val) end -- Mimics NetworkVarNotify signature

		-- Call the OnChanged function in the extension. For example a setting called "MaxPerks" will run EXT:OnMaxPerksChanged(old, new)
		local f = extension["On"..key.."Changed"]
		if f then f(extension, old, val) end

		return true
	end
end

local settingsetfunction = NZU_SANDBOX and function(extension, key, val)
	-- Sandbox implementation: Always network! :D
	if extension.Settings and extension.Settings[key] then
		

		net.Start("nzu_extension_setting")
			net.WriteString(extension.ID)
			netwritesetting(t[key],key,val)
		net.Broadcast()
	end
end or function(extension, key, val)
	-- nZU implementation: Only network if the setting is marked as Client
	if extension.Settings and extension.Settings[key] then
		local old = extension[key]
		local t = extension.Settings[key]

		if t.Parse then val = t:Parse(val) end

		extension[key] = val
		if t.Notify then t:Notify(extension, key, old, val) end -- Mimics NetworkVarNotify signature
		local f = extension["On"..key.."Changed"]
		if f then f(extension, old, val) end

		if t.Client then
			net.Start("nzu_extension_setting")
				net.WriteString(extension.ID)
				netwritesetting(t[key],key,val)
			net.Broadcast()
		end
	end
end





--[[-------------------------------------------------------------------------
Extension Creation
---------------------------------------------------------------------------]]

local function createdefault(id)
	return {ID = id, SetSetting = SERVER and settingsetfunction or nil}
end

local function CompleteSettings(data)
	if data.Settings then
		for k,v in pairs(data.Settings) do
			if SERVER or NZU_SANDBOX or v.Client then
				if v.Type and customtypes[v.Type] then
					-- Inherit all data from the table that Settings didn't define itself
					for k2,v2 in pairs(customtypes[v.Type]) do
						if v[k2] == nil then v[k2] = v2 end
					end
				end

				if data[k] == nil then data[k] = v.Default end
			end
		end
	end
end

--[[-------------------------------------------------------------------------
Loading Extensions from folders in /lua/nzombies-unlimited/extensions/
---------------------------------------------------------------------------]]

local extensionpath = "nzombies-unlimited/extensions/"
local searchpath = "GAME"
local prefix = "lua/"

local function IsValidExtension(name)
	return file.Exists(prefix..extensionpath..name.."/info.lua", searchpath)
end

local function LoadExtensionFromFolder(name, settings)
	local old = EXT
	EXT = nzu.Extensions[name] or createdefault(id)

	-- Provide access to settings during load if they were given by a config save file (or passed onto nzu.LoadExtension directly)
	if settings then
		for k,v in pairs(settings) do
			EXT[k] = v
		end
	end

	local settingsfile = extensionpath..name.."/settings.lua"
	if file.Exists(prefix..settingsfile, searchpath) then
		include(settingsfile)
		CompleteSettings(EXT)
	end

	local filename = extensionpath..name.."/shared.lua"
	if file.Exists(prefix..filename, searchpath) then
		include(filename)
	end

	local extension = EXT
	EXT = old
	return extension
end


--[[-------------------------------------------------------------------------
nZU Interface: Functions on the nzu module that lets you load Extensions
	+ Networking of loading and settings
---------------------------------------------------------------------------]]
if SERVER then
	util.AddNetworkString("nzu_extension_load")

	local function networkextension(ext)
		net.WriteString(ext.ID)

		if ext.Settings then
			local setts = {}

			for k,v in pairs(ext.Settings) do
				if ext[k] and (NZU_SANDBOX or v.Client) and ext[k] ~= v.Default then -- Only network if: Setting exists, it's Sandbox or the setting is Client, and it's not just default
					table.insert(setts, {v, k, ext[k]})
				end
			end

			net.WriteUInt(#setts, 8) -- Do we need more than 255 settings? xD
			for k,v in pairs(setts) do
				netwritesetting(v[1],v[2],v[3])
			end
		end
	end

	function nzu.LoadExtension(name, settings)
		if IsValidExtension(name) then
			local ext = LoadExtensionFromFolder(name, settings)

			local prev = nzu.Extensions[name]
			if prev then
				-- This mimics the style of SWEPs and ENTs who can have Reloaded functions for whenever there's a lua refresh
				if prev.OnReloaded then prev:OnReloaded() end
			else
				nzu.Extensions[name] = ext

				-- This is called after the extension has fully loaded, and all settings have applied
				if ext.Initialize then ext:Initialize() end
			end

			net.Start("nzu_extension_load")
				networkextension(ext)
			net.Broadcast()
		end
	end

else

	net.Receive("nzu_extension_load", function()
		local id = net.ReadString()
		local num = net.ReadUInt(8)

		local prev = nzu.Extensions[id]
		local ext = prev or createdefault(id)

		local old = EXT
		if not prev then
			EXT = ext

			local settingsfile = extensionpath..name.."/settings.lua"
			if file.Exists(prefix..settingsfile, searchpath) then
				include(settingsfile)
				CompleteSettings(ext)
			end
		end

		for i = 1,num do
			local k = net.ReadString()

			local old2 = ext[k]
			ext[k] = netreadsetting(ext.Settings[k])

			-- This callback will only exist if there was previously one loaded; which means all callbacks run even for a bulk-update :D
			local f = ext["On"..k.."Changed"]
			if f then f(ext, old, ext[k]) end
		end

		if not prev then
			local filename = extensionpath..name.."/shared.lua"
			if file.Exists(prefix..filename, searchpath) then
				include(filename)
			end

			EXT = old
		end
	end)
end