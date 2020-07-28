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
Set up the base extension table that extensions will inherit from
---------------------------------------------------------------------------]]
local extensionbase = {}



--[[-------------------------------------------------------------------------
Extension Creation
---------------------------------------------------------------------------]]

local function createdefault(id)
	local t = {ID = id}
	for k,v in pairs(extensionbase) do
		t[k] = v
	end
	return t
end

local function RebuildPanels(self)
	if self.Panels then
		for k,v in pairs(self.Panels) do
			if IsValid(v) then
				v:Rebuild()
			else
				self.Panels[k] = nil
			end
		end
	end
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
				v.RebuildPanels = RebuildPanels

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
	local function dochangesetting(self, key, val)
		local t = self.Settings and self.Settings[key]
		if t then
			local old = self[key]

			if t and t.Parse then val = t:Parse(val) end
			self[key] = val

			if t and t.Notify then t:Notify(self, key, old, val) end -- Mimics NetworkVarNotify signature
			local f = self["On"..key.."Changed"]
			if f then f(self, old, val) end

			return t, val
		end
	end

	-- Adding EXTENSION:SetSetting, which parses, runs Notify and On[X]Changed callbacks, and then networks just this setting
	if NZU_SANDBOX then
		function extensionbase:SetSetting(key, val)
			-- Sandbox implementation: Always network! :D
			local t, val = dochangesetting(self, key, val)
			if t then
				net.Start("nzu_extension_setting")
					net.WriteString(self.ID)
					netwritesetting(t,key,val)
				net.Broadcast()
			end
		end
	else
		function extensionbase:SetSetting(key, val)
			-- nZU implementation: Only network if the setting is marked as Client
			local t, val = dochangesetting(self, key, val)
			if t and t.Client then
				net.Start("nzu_extension_setting")
					net.WriteString(self.ID)
					netwritesetting(t,key,val)
				net.Broadcast()
			end
		end
	end

	util.AddNetworkString("nzu_extension_load")
	local function networkextension(ext, settings)
		net.WriteString(ext.ID)
		local t = settings or ext.Settings

		if t then
			local setts = {}

			for k,v in pairs(t) do
				if ext[k] and (NZU_SANDBOX or v.Client) and ext[k] ~= v.Default then -- Only network if: Setting exists, it's Sandbox or the setting is Client, and it's not just default
					table.insert(setts, {v, k, ext[k]})
				end
			end

			net.WriteUInt(#setts, 8) -- Do we need more than 255 settings? xD
			for k,v in pairs(setts) do
				netwritesetting(v[1],v[2],v[3])
			end
		else
			net.WriteUInt(0, 8) -- No settings!
		end
	end

	-- Adding EXTENSION:BulkSetSettings(), which bulk-sets a table of key/values of settings. This is network efficient if you intend to change many settings at once, as it goes through the Extension Load network format
	function extensionbase:BulkSetSettings(tbl)
		-- Sandbox implementation: Always network
		local setts = {}
		local any = false
		for k,v in pairs(tbl) do
			local t, val = dochangesetting(self, key, val)
			if t then
				setts[k] = t[k]
				any = true
			end
		end
		
		if any then
			net.Start("nzu_extension_load") -- This "tricks" clients into loading a table of settings into their extension by the ID
				networkextension(ext, setts) -- it's the same logic that is used when an extension is first loaded, with its initial settings from the config
			net.Broadcast()
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

	function nzu.UnloadExtensions(names)
		for k,v in pairs(names) do
			nzu.Extensions[v] = nil
		end

		-- Cause a reboot to unload the code
		nzu.SaveConfig()
		nzu.LoadConfig(nzu.CurrentConfig)
	end

	net.Receive("nzu_extension_load", function(len, ply)
		if not nzu.IsAdmin(ply) or not nzu.CurrentConfig then return end

		if net.ReadBool() then
			nzu.LoadExtension(net.ReadString())
		else
			local num = net.ReadUInt(8)
			if num > 0 then
				local t = {}
				for i = 1,num do
					table.insert(t, net.ReadString())
				end
				nzu.UnloadExtensions(t)
			end
		end
	end)

	hook.Add("PlayerInitialSpawn", "nzu_ExtensionLoad", function(ply)
		for k,v in pairs(nzu.Extensions) do
			net.Start("nzu_extension_load")
				networkextension(v)
			net.Send(ply)
		end
	end)

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

	function nzu.RequestLoadExtension(name)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_extension_load")
			net.WriteString(name)
		net.SendToServer()
	end
end





--[[-------------------------------------------------------------------------
Extension availability and networking load requests
---------------------------------------------------------------------------]]
function nzu.GetInstalledExtensionList()
	local tbl = {}

	for k,v in pairs(nzu.Extensions) do
		table.insert(tbl, k)
	end

	local _,dirs = file.Find(prefix..extensionpath.."*", searchpath)
	for k,v in pairs(dirs) do
		if not nzu.Extensions[v] and IsValidExtension(v) then
			table.insert(tbl, v)
		end
	end
	return tbl
end

function nzu.GetExtensionDetails(name)
	local str = file.Read(prefix..extensionpath..name.."/info.lua", searchpath)
	if str then
		return util.JSONToTable(str)
	end
end

if NZU_SANDBOX then
	if SERVER then
		util.AddNetworkString("nzu_extensions")
		local function networkextensionavailability(name, ply)
			local data = nzu.GetExtensionDetails(name)
			net.Start("nzu_extensions")
				net.WriteString(name)
				net.WriteString(data.Name)
				net.WriteString(data.Description)
				net.WriteString(data.Author)
				
				local num = data.Prerequisites and #data.Prerequisites or 0
				net.WriteUInt(num, 8)
				for i = 1,num do
					net.WriteString(data.Prerequisites[i])
				end
			if ply then net.Send(ply) else net.Broadcast() end
		end
		
		hook.Add("PlayerInitialSpawn", "nzu_Extensions_NetworkList", function(ply)
			for k,v in pairs(nzu.GetInstalledExtensionList()) do
				networkextensionavailability(v, ply)
			end
		end)
	else
		local availableextensions = {}
		net.Receive("nzu_extensions", function()
			local id = net.ReadString()
			local ext = {ID = id}
			ext.Name = net.ReadString()
			ext.Description = net.ReadString()
			ext.Author = net.ReadString()
			
			local num = net.ReadUInt(8)
			if num > 0 then
				ext.Prerequisites = {}
				for i = 1,num do
					table.insert(ext.Prerequisites, net.ReadString())
				end
			end
			
			availableextensions[id] = ext
		end)
		
		function nzu.GetAvailableExtensions()
			return availableextensions
		end
		
		function nzu.GetExtensionDetails(id)
			return availableextensions[id]
		end
	end
end