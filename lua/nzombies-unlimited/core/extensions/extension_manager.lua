
local extensionpath = "nzombies-unlimited/extensions/"
local searchpath = "GAME"
local prefix = "lua/"

function nzu.IsValidExtension(name)
	return file.Exists(prefix..extensionpath..name.."/extension.json", searchpath)
end

function nzu.GetExtensionDetails(name)
	local str = file.Read(prefix..extensionpath..name.."/extension.json", searchpath)
	if str then
		return util.JSONToTable(str)
	end
end

local loaded_extensions = {}
function nzu.GetLoadedExtensionList() return loaded_extensions end
function nzu.GetExtensionList()
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

local function netwritesetting(tbl,set,val)
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






--[[-------------------------------------------------------------------------
Generating Extensions from files
---------------------------------------------------------------------------]]
local loadingextension
function nzu.Extension() return loadingextension end
local function loadextension(name, st)
	loadingextension = {ID = name}

	local settings, panelfunc
	local filename = extensionpath..name.."/settings.lua"
	if file.Exists(prefix..filename, searchpath) then
		AddCSLuaFile(filename)
		settings, panelfunc = include(filename)

		if settings then
			if SERVER then
				local t = {}
				for k,v in pairs(settings) do
					t[k] = st and st[k] or v.Default
				end

				if NZU_SANDBOX then
					-- Calling the settings table with a field as first argument and value as second will set it and network it
					-- In Sandbox, it always does this with all settings
					setmetatable(t, {__call = function(tbl,k,v)
						if settings[k].Parse then v = settings[k].Parse(v) end
						tbl[k] = v -- Actually set the value of course

						net.Start("nzu_extension_setting")
							net.WriteString(loadingextension.ID)
							netwritesetting(settings,k,v)
						net.Broadcast()

						hook.Run("nzu_ExtensionSettingChanged", loadingextension.ID, k, v)
					end})
				else
					-- In nZombies, only network settings that are marked as Client = true
					setmetatable(t, {__call = function(tbl,k,v)
						if settings[k].Parse then v = settings[k].Parse(v) end
						tbl[k] = v

						if settings[k].Client then
							net.Start("nzu_extension_setting")
								net.WriteString(loadingextension.ID)
								netwritesetting(settings,k,v)
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
	end
	loadingextension.GetSettingsMeta = function() return settings end
	if CLIENT then loadingextension.GetPanelFunction = function() return panelfunc end end

	-- Load the actual files
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

	loaded_extensions[name] = loadingextension
	loadingextension = nil

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

	local function networkextension(ext)
		net.WriteString(ext.ID)
		net.WriteBool(true)

		if ext.Settings then
			local sm = ext.GetSettingsMeta()
			for k,v in pairs(ext.Settings) do
				if NZU_SANDBOX or sm[k].Client then
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
		load_order = {}
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

		local ext = loadextension(name, settings)
		if NZU_SANDBOX then
			table.insert(load_order, ext.ID)
		end
		net.Start("nzu_extension_load")
			networkextension(ext)
		net.Broadcast()
	end

	net.Receive("nzu_extension_load", function(len, ply)
		if not nzu.IsAdmin(ply) then return end
		nzu.LoadExtension(net.ReadString())
	end)

	hook.Add("PlayerInitialSpawn", "nzu_ExtensionLoad", function(ply)
		for k,v in pairs(loaded_extensions) do
			net.Start("nzu_extension_fullsync")
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
			local ext = loadextension(name)

			if ext.Settings then
				local sm  = ext.GetSettingsMeta()
				while net.ReadBool() do
					local k = net.ReadString()
					if sm[k] then
						ext.Settings[k] = netreadsetting(sm[k])
					end
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
		if not nzu.IsAdmin(ply) then
			-- Not an admin, network back the old value to correct them back
			ply:ChatPrint("You cannot change this Extension setting without being an Admin.")
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
			local v = netreadsetting(ext.GetSettingsMeta()[k])
			ext.Settings[k] = v

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
end