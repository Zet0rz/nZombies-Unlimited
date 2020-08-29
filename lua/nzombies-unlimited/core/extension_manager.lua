-- Extensions. A code object that can contain functions and values local to that extension.
-- It is ID-based and may contain a special "Settings" field. This field lets the gamemode know how to parse and network values
-- when they are changed through the Extension's given "SetSetting" function.
nzu.Extensions = nzu.Extensions or {}
local loaded_extensions = nzu.Extensions

function nzu.GetExtension(name) return loaded_extensions[name] end
function nzu.IsExtensionLoaded(name) return loaded_extensions[name] and true or false end
function nzu.GetLoadedExtensions() return loaded_extensions end


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
local readtypes = net.ReadVars

-- Adding our own custom TYPEs
local customtypes = {}
function nzu.AddExtensionSettingType(type, tbl)
	tbl.__index = tbl

	-- A bit of cleanup
	if SERVER then
		tbl.Panel = nil
		tbl.Label = nil
		tbl.ZPos = nil
	end

	customtypes[type] = tbl
end
function nzu.GetExtensionSettingType(type)
	return customtypes[type]
end

local function netwritesetting(tbl,set,val)
	net.WriteString(set)
	if tbl.NetWrite then
		tbl:NetWrite(val)
	elseif tbl.NetType then
		writetypes[tbl.NetType](val)
	end
end
local function netreadsetting(tbl)
	if tbl.NetRead then
		return tbl:NetRead()
	elseif tbl.NetType then
		return readtypes[tbl.NetType]()
	end
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
	EXT = loaded_extensions[name] or createdefault(id)

	local settingsfile = extensionpath..name.."/settings.lua"
	if file.Exists(prefix..settingsfile, searchpath) then
		include(settingsfile)
		CompleteSettings(EXT)
	end

	-- Provide access to settings during load if they were given by a config save file (or passed onto nzu.LoadExtension directly)
	if settings then
		for k,v in pairs(settings) do
			local t = EXT.Settings and EXT.Settings[k]
			EXT[k] = t and t.Parse and t:Parse(v) or v
		end
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
SERVER STUFF FIRST
In order:
- Local functions
- Extension base functions
- Networking (first strings, then receivers)
- Hooks and necessary gmod integrations
- Accessible "nzu." global functions
---------------------------------------------------------------------------]]
if SERVER then


	-- LOCALS

	-- Perform the change of a setting on an extension, parsing the value and calling necessary hooks and callbacks.
	local function dochangesetting(self, key, val)
		local t = self.Settings and self.Settings[key]
		if t then
			local old = self[key]

			if t.Parse then val = t:Parse(val) end
			self[key] = val

			if t.Notify then t:Notify(self, key, old, val) end -- Mimics NetworkVarNotify signature
			local f = self["On"..key.."Changed"]
			if f then f(self, old, val) end

			hook.Run("nzu_ExtensionSettingChanged", self.ID, key, val)

			return t, val
		end
	end

	-- Network an extension, sending the ID of it as well as every setting (if it should be networked) to all clients
	local function networkextension(ext, settings)
		net.WriteString(ext.ID)
		local t = settings or ext.Settings

		if t then
			local setts = {}

			for k,v in pairs(t) do
				if ext[k] and (NZU_SANDBOX or v.Client) then -- Only network if: Setting exists, it's Sandbox or the setting is Client
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





	-- EXTENSION BASE

	-- EXTENSION:SetSetting(): Performs a setting change and networks the changed value individually
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

	-- EXTENSION:BulkSetSettings(): Takes a table with keys of setting keys and values of the value to set them to respectively. Networks them all in a single bulk.
	function extensionbase:BulkSetSettings(tbl)
		-- Sandbox implementation: Always network
		local setts = {}
		local any = false
		for k,v in pairs(tbl) do
			local t, val = dochangesetting(self, k, v)
			if t and (NZU_SANDBOX or t.Client) then
				setts[k] = t[k]
				any = true
			end
		end
		
		if any then
			net.Start("nzu_extension_load") -- This "tricks" clients into loading a table of settings into their extension by the ID
				networkextension(self, setts) -- it's the same logic that is used when an extension is first loaded, with its initial settings from the config
			net.Broadcast()
		end
	end



	-- NETWORKING
	util.AddNetworkString("nzu_extension_load") -- SERVER: Make clients load extension files/Full sync all settings || CLIENT: Request loading of extension (Sandbox), Request full setting sync (nZombies)
	util.AddNetworkString("nzu_extension_setting") -- SERVER: Network a setting to clients || CLIENT: Request setting change

	-- Server "nzu_extension_load": Accept a request to load an Extension, or unload a list of extensions.
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

	-- Server "nzu_extension_setting": Accept a request to change the settings of an Extension.
	net.Receive("nzu_extension_setting", function(len, ply)
		if NZU_NZOMBIES and not nzu.IsAdmin(ply) then
			-- Only admins can change it in nZU
			ply:ChatPrint("You cannot change Extension Settings without being an Admin.")
		return end
		
		local ext = loaded_extensions[net.ReadString()]
		if ext and ext.Settings then
			local k = net.ReadString()
			-- Since __call causes networking, this will network
			ext:SetSetting(k, netreadsetting(ext.Settings[k]))
		end
	end)


	-- HOOKS

	-- Whenever a new player joins in, have them load all loaded extensions as well
	hook.Add("PlayerInitialSpawn", "nzu_ExtensionLoad", function(ply)
		for k,v in pairs(loaded_extensions) do
			net.Start("nzu_extension_load")
				networkextension(v)
			net.Send(ply)
		end
	end)


	-- GLOBAL nzu. FUNCTIONS

	-- nzu.LoadExtension(): Loads an extension by a given name and optionally a table of setting values
	function nzu.LoadExtension(name, settings)
		if IsValidExtension(name) then
			local ext = LoadExtensionFromFolder(name, settings)

			local prev = loaded_extensions[name]
			if prev then
				-- This mimics the style of SWEPs and ENTs who can have Reloaded functions for whenever there's a lua refresh
				if prev.OnReloaded then prev:OnReloaded() end
			else
				loaded_extensions[name] = ext

				-- This is called after the extension has fully loaded, and all settings have applied
				if ext.Initialize then ext:Initialize() end
			end

			net.Start("nzu_extension_load")
				networkextension(ext)
			net.Broadcast()
		end
	end

	-- nzu.UnloadExtensions(): Takes a table of IDs of extensions to unload. It removes them from the extension list, saves the config, then reloads the map to reload the code.
	function nzu.UnloadExtensions(names)
		for k,v in pairs(names) do
			loaded_extensions[v] = nil
		end

		-- Cause a reboot to unload the code
		nzu.SaveConfig()
		nzu.LoadConfig(nzu.CurrentConfig)
	end
else
	--[[-------------------------------------------------------------------------
	CLIENT TIME
	---------------------------------------------------------------------------]]

	-- LOCALS

	-- A copy of the server-side function, but this one doesn't parse and doesn't check against whether the setting exists
	-- On client this also updates the relevant panel, if it exists
	local function dochangesetting(self, key, val)
		local t = self.Settings and self.Settings[key]
		local old = self[key]
		self[key] = val

		if t and t.Notify then t:Notify(self, key, old, val) end -- Mimics NetworkVarNotify signature
		local f = self["On"..key.."Changed"]
		if f then f(self, old, val) end

		-- Update all panels!
		if self.Panels then
			for k,v in pairs(self.Panels) do
				local p = k.Settings[key]
				if IsValid(p) then p:SetValue(val) end
			end
		end

		hook.Run("nzu_ExtensionSettingChanged", self.ID, key, val)

		return t, val
	end




	-- EXTENTION BASE

	-- Request setting changes
	function extensionbase:RequestChangeSetting(key, value)
		if not nzu.IsAdmin(LocalPlayer()) then return end -- Only admins can change settings!

		local t = self.Settings and self.Settings[key]
		if t then
			if t.Parse then value = t:Parse(value) end

			net.Start("nzu_extension_setting")
				net.WriteString(self.ID)
				netwritesetting(t,key,value)
			net.SendToServer()
		end
	end

	-- Create a panel networked to this extension
	function extensionbase:CreatePanel()
		local p = vgui.Create("nzu_ExtensionPanel")
		p:SetExtension(extension)

		return p
	end

	-- Create a single networked panel for a single setting in this Extension
	-- The panel from CreatePanel() uses these
	--[[function extensionbase:CreateSettingPanel(key, parent, tbl)
		local t = tbl or self.Settings[key]
		if t and t.Panel then
			local p = t:Panel(parent)
			p.SettingKey = key
			p.Send = sendnetwork

			p.Extension = self.Extension
			p.SetValueNoNetwork = setvaluenonetwork

			if not t.Panels then 

			p:SetValueNoNetwork(self[key])
		end
	end]]




	-- NETWORKING

	-- Client "nzu_extension_load": Receive commands to load extensions, as well as networked settings. It first loads settings.lua in order to allow it to read the networked settings, then load the rest of the code
	-- This is also used to bulk-update an extension, as the code will not reload if it's already loaded (but will just change the settings)
	net.Receive("nzu_extension_load", function()
		local id = net.ReadString()
		local num = net.ReadUInt(8)

		local prev = loaded_extensions[id]
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

			-- The "OnChanged" callbacks will only exist if the extension was previously loaded; which means all callbacks run even for a bulk-update :D
			dochangesetting(ext, k, netreadsetting(ext.Settings[k]))
		end

		if not prev then
			local filename = extensionpath..name.."/shared.lua"
			if file.Exists(prefix..filename, searchpath) then
				include(filename)
			end

			EXT = old
		end
	end)

	-- Client "nzu_extension_setting": Accept a command to change a single setting on a single extension
	net.Receive("nzu_extension_setting", function(len)
		local ext = loaded_extensions[net.ReadString()]
		if ext and ext.Settings then
			local k = net.ReadString()
			dochangesetting(ext, k, netreadsetting(ext.Settings[k]))
		end
	end)




	-- GLOBAL nzu. FUNCTIONS

	-- Request the server to load an extension
	function nzu.RequestLoadExtension(name)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_extension_load")
			net.WriteBool(true)
			net.WriteString(name)
		net.SendToServer()
	end

	-- Request the server to unload a list of extensions
	function nzu.RequestUnloadExtensions(names)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_extension_load")
			net.WriteBool(false)
			net.WriteUInt(#names, 8)
			for k,v in pairs(names) do
				net.WriteString(v)
			end
		net.SendToServer()
	end
end






--[[-------------------------------------------------------------------------
Extension availability and networking load requests
---------------------------------------------------------------------------]]
function nzu.GetInstalledExtensionList()
	local tbl = {}

	for k,v in pairs(loaded_extensions) do
		table.insert(tbl, k)
	end

	local _,dirs = file.Find(prefix..extensionpath.."*", searchpath)
	for k,v in pairs(dirs) do
		if not loaded_extensions[v] and IsValidExtension(v) then
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
		util.AddNetworkString("nzu_extension_availability")
		local function networkextensionavailability(name, ply)
			local data = nzu.GetExtensionDetails(name)
			net.Start("nzu_extension_availability")
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
		local availableextensions = {["core"] = {Name = "Core", Description = "Debug", Author = "Zet0r"}}
		net.Receive("nzu_extension_availability", function()
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


--[[-------------------------------------------------------------------------
The Core settings
---------------------------------------------------------------------------]]
local core = loaded_extensions.core or createdefault("core")
loaded_extensions.core = core

include(extensionpath.."core/settings.lua")
CompleteSettings(core)

--[[-------------------------------------------------------------------------
AddCSLuaFile'ing all extensions that could potentially be loaded
Clients need these when they JOIN, or they won't be able to load them, even if they are dynamically loaded
It sucks that you have to do this, but that's how it be sometimes

Add all files in all valid extensions that do not start with "sv_"
Exception is info.lua as this is only needed server side
---------------------------------------------------------------------------]]
if SERVER then
	local _, dirs = file.Find(prefix..extensionpath.."*", searchpath)
	for k,v in pairs(dirs) do
		if IsValidExtension(v) then
			for k2,v2 in pairs(file.Find(prefix..extensionpath..v.."/*.lua", searchpath)) do
				if v2 ~= "info.lua" and string.sub(v2, 1, 3) ~= "sv_" then
					AddCSLuaFile(extensionpath..v.."/"..v2)
				end
			end
		end
	end
end