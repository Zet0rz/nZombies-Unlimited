
local extensionpath = "nzombies-unlimited/extensions/"
local searchpath = "GAME"
local prefix = "lua/"

function nzu.IsValidExtension(name)
	return file.Exists(prefix..extensionpath..name.."/info.lua", searchpath)
end

function nzu.GetExtensionDetails(name)
	local str = file.Read(prefix..extensionpath..name.."/info.lua", searchpath)
	if str then
		return util.JSONToTable(str)
	end
end

local loaded_extensions = nzu.Extensions or {}
nzu.Extensions = loaded_extensions
function nzu.GetLoadedExtensionList() return loaded_extensions end
function nzu.GetExtensionList()
	local tbl = {}

	for k,v in pairs(loaded_extensions) do
		table.insert(tbl, k)
	end

	local _,dirs = file.Find(prefix..extensionpath.."*", searchpath)
	for k,v in pairs(dirs) do
		if not loaded_extensions[v] and nzu.IsValidExtension(v) then
			table.insert(tbl, v)
		end
	end
	return tbl
end



--[[-------------------------------------------------------------------------
Networking Extension availability
---------------------------------------------------------------------------]]
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
			for k,v in pairs(nzu.GetExtensionList()) do
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
Generating Extensions from files
---------------------------------------------------------------------------]]
local loadingextension2
function nzu.Extension()
	return loadingextension2
end

-- This function prepares the settings meta
-- "loadextension" should be called with the return of this value once settings are loaded/prepared (if any)
-- To use defaults, these can just be chained [loadextension(loadextensionprepare(name))]
local function loadextensionprepare(name, hassettings)
	local loadingextension = loaded_extensions[name] or {ID = name}
	local settings, panelfunc
	
	if hassettings then
		local filename = extensionpath..name.."/settings.lua"
		settings, panelfunc = include(filename)
		loadingextension.HasSettingsFile = true
	end

	if settings then
		-- Inherit from custom types
		for k,v in pairs(settings) do
			if v.Type and customtypes[v.Type] then
				-- Inherit all data from the table that Settings didn't define itself
				setmetatable(v, customtypes[v.Type])
				--for k2,v2 in pairs(customtypes[v.Type]) do
					--if v[k2] == nil then v[k2] = v2 end
				--end
			end

			if SERVER or NZU_SANDBOX or v.Client then
				if v.Create then v.Create(loadingextension, k, v) end
			else
				settings[k] = nil
			end
		end

		if SERVER then
			local t = {}
			if NZU_SANDBOX then
				-- Calling the settings table with a field as first argument and value as second will set it and network it
				-- In Sandbox, it always does this with all settings
				setmetatable(t, {__call = function(tbl,k,v)
					local s = settings[k]
					if s.Parse then v = s.Parse(v) end
					tbl[k] = v -- Actually set the value of course
					if s.Notify then s.Notify(k,v) end

					net.Start("nzu_extension_setting")
						net.WriteString(loadingextension.ID)
						netwritesetting(settings[k],k,v)
					net.Broadcast()

					hook.Run("nzu_ExtensionSettingChanged", loadingextension.ID, k, v)
				end})
			else
				-- In nZombies, only network settings that are marked as Client = true
				setmetatable(t, {__call = function(tbl,k,v)
					local s = settings[k]
					if s.Parse then v = s.Parse(v) end
					tbl[k] = v
					if s.Notify then s.Notify(k,v) end

					if s.Client then
						net.Start("nzu_extension_setting")
							net.WriteString(loadingextension.ID)
							netwritesetting(settings[k],k,v)
						net.Broadcast()
					end

					hook.Run("nzu_ExtensionSettingChanged", loadingextension.ID, k, v)
				end})
			end

			loadingextension.Settings = t
		else
			loadingextension.Settings = {} -- Empty for clients by default; we wait expected networking here
		end
	end
	loadingextension.GetSettingsMeta = function() return settings end
	if CLIENT then
		loadingextension.GetPanelFunction = function() return panelfunc end
		loadingextension.RebuildPanels = function() end
	end

	return loadingextension
end

-- This function applies a table of settings, and loads the code of the extension afterwards
-- After calling this function, the Extension will be ready and active
local function loadextension(loadingextension, st)
	loadingextension2 = loadingextension

	local t = loadingextension.Settings
	local notifies
	if t then
		notifies = {}
		if SERVER or NZU_SANDBOX then -- On Server or in Sandbox: Read every settings field
			for k,v in pairs(loadingextension.GetSettingsMeta()) do
				t[k] = st and st[k] or v.Default

				if SERVER then
					if v.Load then t[k] = v.Load(t[k]) end
				end

				if v.Notify then notifies[k] = {v.Notify, t[k]} end
			end
		elseif CLIENT and st then -- On Client and not in Sandbox: Only read settings in the 'st' table
			for k,v in pairs(st) do
				t[k] = st[k]

				local notify = loadingextension.GetSettingsMeta()[k].Notify
				if notify then notifies[k] = {notify, t[k]} end
			end
		end
	end

	-- Load the actual files
	local name = loadingextension.ID
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

	if notifies then
		for k,v in pairs(notifies) do
			v[1](v[2],k)
		end
	end

	loaded_extensions[name] = loadingextension
	loadingextension2 = nil

	hook.Run("nzu_ExtensionLoaded", name)

	return loaded_extensions[name]
end
function nzu.GetExtension(name) return loaded_extensions[name] end
function nzu.IsExtensionLoaded(name) return loaded_extensions[name] and true or false end








--[[-------------------------------------------------------------------------
Loading Extensions
---------------------------------------------------------------------------]]
if SERVER then
	util.AddNetworkString("nzu_extension_load") -- SERVER: Make clients load extension files/Full sync all settings || CLIENT: Request loading of extension (Sandbox), Request full setting sync (nZombies)

	local function networkextension(ext, update)
		net.WriteString(ext.ID)
		net.WriteBool(true)
		if not update then
			net.WriteBool(true)
			net.WriteBool(ext.HasSettingsFile)
		else
			net.WriteBool(false)
		end

		if ext.Settings then
			local sm = ext.GetSettingsMeta()
			for k,v in pairs(ext.Settings) do
				if sm[k] and (NZU_SANDBOX or sm[k].Client) then
					net.WriteBool(true)
					netwritesetting(sm[k],k,v)
				end
			end
		end
		net.WriteBool(false) -- Stop the recursive settings reading
	end

	-- This lets us ensure prerequisite loading properly by remembering load order - since clients can only load them in order of prerequisites
	local load_order
	if NZU_SANDBOX then
		load_order = {[1] = "Core"}
		function nzu.GetLoadedExtensionOrder() return load_order end
	end

	function nzu.LoadExtension(name, settings, force)
		if not force then
			local details = nzu.GetExtensionDetails(name)
			if not details then return false end
			if details.Prerequisites then
				for k,v in pairs(details.Prerequisites) do
					if not loaded_extensions[v] then return false end
				end
			end
		end

		local hassettings = file.Exists(prefix..extensionpath..name.."/settings.lua", searchpath)
		local ext = loadextension(loadextensionprepare(name, hassettings), settings)
		if NZU_SANDBOX then
			table.insert(load_order, ext.ID)
		end
		net.Start("nzu_extension_load")
			networkextension(ext)
		net.Broadcast()
	end

	function nzu.UnloadExtensions(names)
		for k,v in pairs(names) do
			loaded_extensions[v] = nil
		end

		-- Cause a reboot to unload the code
		nzu.SaveConfig()
		nzu.LoadConfig(nzu.CurrentConfig)
	end

	function nzu.UpdateExtension(name, settings)
		local ext = loaded_extensions[name]
		if ext and ext.Settings then
			for k,v in pairs(settings) do
				ext.Settings[k] = v
				hook.Run("nzu_ExtensionSettingChanged", name, k, v)
			end

			net.Start("nzu_extension_load")
				networkextension(ext, true)
			net.Broadcast()
		end
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
		for k,v in pairs(loaded_extensions) do
			net.Start("nzu_extension_load")
				networkextension(v)
			net.Send(ply)
		end
	end)
else
	function nzu.RequestLoadExtension(name)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_extension_load")
			net.WriteString(name)
		net.SendToServer()
	end

	net.Receive("nzu_extension_load", function()
		local name = net.ReadString()
		if net.ReadBool() then
			local b = net.ReadBool()
			local ext = b and loadextensionprepare(name, net.ReadBool()) or loaded_extensions[name]

			local sm = ext.GetSettingsMeta()
			local settings
			if sm then
				settings = {}
				while net.ReadBool() do
					local k = net.ReadString()
					if sm[k] then
						settings[k] = netreadsetting(sm[k])
					end
				end
			end

			if b then
				loadextension(ext, settings)
			else
				for k,v in pairs(settings) do
					ext.Settings[k] = v
					hook.Run("nzu_ExtensionSettingChanged", name, k, v)
				end
			end
		elseif loaded_extensions[name] then
			loaded_extensions[name] = nil
		end
	end)
end



if SERVER then
	util.AddNetworkString("nzu_extension_setting") -- SERVER: Network a setting to clients || CLIENT: Request setting change

	net.Receive("nzu_extension_setting", function(len, ply)
		if NZU_NZOMBIES and not nzu.IsAdmin(ply) then
			-- Only admins can change it in nZU
			ply:ChatPrint("You cannot change Extension Settings without being an Admin.")
		return end
		
		local ext = loaded_extensions[net.ReadString()]
		if ext and ext.Settings then
			local k = net.ReadString()
			-- Since __call causes networking, this will network
			ext.Settings(k, netreadsetting(ext.GetSettingsMeta()[k]))
		end
	end)

	-- Give an alias to networking settings
	function nzu.SetExtensionSetting(ext, setting, value)
		if type(ext) == "string" then ext = nzu.GetExtension(ext) end
		if ext.Settings then
			ext.Settings(setting, value)
		end
	end
else
	net.Receive("nzu_extension_setting", function(len)
		local ext = loaded_extensions[net.ReadString()]
		if ext and ext.Settings then
			local k = net.ReadString()
			local s = ext.GetSettingsMeta()[k]
			local v = netreadsetting(s)
			ext.Settings[k] = v

			if s.Notify then s.Notify(v,k) end

			hook.Run("nzu_ExtensionSettingChanged", ext.ID, k, v)
		end
	end)

	-- Request setting changes
	function nzu.RequestExtensionSetting(ext, setting, value)
		if type(ext) == "string" then ext = nzu.GetExtension(ext) end
		if not ext or not ext.Settings then return end

		local settingtbl = ext.GetSettingsMeta()[setting]
		if settingtbl then
			if settingtbl.Parse then value = settingtbl.Parse(value) end

			net.Start("nzu_extension_setting")
				net.WriteString(ext.ID)
				netwritesetting(settingtbl,setting,value)
			net.SendToServer()
		end
	end

	function nzu.RequestLoadExtension(name)
		if not nzu.IsAdmin(LocalPlayer()) then return end
		net.Start("nzu_extension_load")
			net.WriteBool(true)
			net.WriteString(name)
		net.SendToServer()
	end

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
AddCSLuaFile'ing

Kinda sucks that you have to do this before clients connect, so we HAVE
to AddCSLuaFile every possible file that a client could run :/
---------------------------------------------------------------------------]]
if SERVER then
	local _,dirs = file.Find(prefix..extensionpath.."*", searchpath)
	for k,v in pairs(dirs) do
		if nzu.IsValidExtension(v) then
			local details = nzu.GetExtensionDetails(v)
			local files
			if NZU_SANDBOX then
				files = {"sandbox", "settings"}
				if details.ClientFiles_Sandbox then table.Add(files, details.ClientFiles_Sandbox) end
			elseif NZU_NZOMBIES then
				files = {"nzombies", "settings"}
				if details.ClientFiles_nZombies then table.Add(files, details.ClientFiles_nZombies) end
			end

			local prefix2 = extensionpath..v.."/"
			for k2,v2 in pairs(files) do
				if file.Exists(prefix..prefix2..v2..".lua", searchpath) then
					AddCSLuaFile(prefix2..v2..".lua")
				end
			end
		end
	end
end



--[[-------------------------------------------------------------------------
Load Core extension at this point - this happens no matter what, and before any
other Extension.

The Core extension doesn't actually contain any code, instead just proxies
settings used by the main gamemode.
---------------------------------------------------------------------------]]
-- This is needed here cause Core uses some of these for its settings
if SERVER then
	AddCSLuaFile("hudmanagement.lua")
	AddCSLuaFile("resources.lua")
end
include("resources.lua")
include("hudmanagement.lua")



loadextension(loadextensionprepare("Core", true))