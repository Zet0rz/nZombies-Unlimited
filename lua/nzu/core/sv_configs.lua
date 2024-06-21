--[[-------------------------------------------------------------------------
Configs as a class - Metatable
---------------------------------------------------------------------------]]

local config_loaders = {}
local loaders,_ = file.Find("lua/nzu/core/configloaders/*.lua", "GAME")
for k,v in pairs(loaders) do
	local loader = include("nzu/core/configloaders/"..v)
	if loader then
		loader.ID = string.StripExtension(v)
		config_loaders[loader.ID] = loader
	end
end

function nzu.GetConfigLoader(format)
	return config_loaders[format]
end

--[[-------------------------------------------------------------------------
Check if a Config exists
---------------------------------------------------------------------------]]
function nzu.ConfigExists(path, codename, format)
	-- If codename is nil, we assume the function only received one argument, and that argument is a direct path
	-- Otherwise, we retrieve the path from this codename, and assume the first argument must be the type
	if codename then
		local loader = config_loaders[format or nzu.LatestConfigFormat]
		if not loader or not loader.Paths[path] then return false end
		path = loader.Paths[path]..codename
	end

	return file.IsDir(path, "GAME")
end

--[[-------------------------------------------------------------------------
Metadata of a Config
---------------------------------------------------------------------------]]
local configfields = {"Format", "Name", "Map", "Authors", "Description", "WorkshopID", "RequiredAddons"}
function nzu.GetConfigMetadata(config)
	if type(config) == "string" then
		local worked, tbl = pcall(util.JSONToTable, file.Read(config.."/info.lua", "GAME") or file.Read(config.."/info.txt", "GAME"))
		if not worked then return end
		config = tbl
	end

	-- Isolate the relevant fields
	local meta = {}
	for k,v in pairs(configfields) do meta[v] = config[v] end
	return meta
end


--[[-------------------------------------------------------------------------
Getting a Config from a Path
---------------------------------------------------------------------------]]
local function infer_format(path, info)
	-- The metadata is enriched with the format
	if info.Format then return info.Format end

	-- Go through all other loaders, until we find one that successfully validates this Config
	-- Configs don't need a Validate function if they only need to check the Format key in the metadata (that is shortcutted above!)
	for k,v in pairs(config_loaders) do
		if v.Validate and v.Validate(path, info) then return k end
	end
end

function nzu.GetConfig(path, codename, format)

	-- If we are given Type, Codename, (Format), use those instead to find the path we're looking for
	-- If we aren't given codename, we assume it means the first argument must be a full path
	local ctype
	if codename then
		format = format or nzu.LatestConfigFormat
		local loader = config_loaders[format or nzu.LatestConfigFormat]
		if not loader or not loader.Paths[path] then return end
		ctype = path
		path = loader.Paths[path]..codename
	end

	-- If this path does not exist, we return nothing
	if not nzu.ConfigExists(path) then return end

	-- Load the metadata. Also use it to infer the load type, if we can
	local meta = nzu.GetConfigMetadata(path)
	if not format then format = infer_format(path, meta) end
	if not format then return end

	-- Set up the config, starting with all the metadata
	local config = {}
	for k,v in pairs(configfields) do config[v] = meta[v] end
	
	-- Add the special-type data, such as path, codename, and type (if known)
	config.Path = path
	if codename then
		config.Codename = codename
		config.Type = ctype
	end

	-- If we have a known format, let it load potential missing information (such as the category and codename, if we were just given a path!)
	-- It could be that this has more complex mechanics that uses multiple files or maybe infers from the path
	if format then config_loaders[format].LoadInfo(config, path) end
	return config
end

-- Little helper function to get the paths given a known load type and a format (or just latest)
function nzu.GetConfigPath(ctype, format)
	format = format or nzu.LatestConfigFormat
	local loader = config_loaders[format]
	return loader and loader.Paths[ctype]
end


--[[-------------------------------------------------------------------------
Finding configs - Filters can be used here, but if left nil, it will just find all
---------------------------------------------------------------------------]]
local find_recursive
find_recursive = function(tbl, configdirs, root, codename)
	if not configdirs then
		for k,v in pairs(config_loaders) do
			find_recursive(tbl, v.Paths, root, codename)
		end
		return
	end

	if not root then
		for k,v in pairs(configdirs) do
			find_recursive(tbl, configdirs, v, codename)
		end
		return
	end

	if not codename then
		local _,codenames = file.Find(root.."/*", "GAME")
		for k,v in pairs(codenames) do
			table.insert(tbl, root..v)
		end
	else
		table.insert(tbl, root..codename)
	end
end

-- Here is the accessible function that executes the recursive above
function nzu.FindConfigs(ctype, map, codename, format)
	local tbl = {}
	local root = nil
	local loader = format and config_loaders[format]
	if format and ctype then
		root = loader and loader.Paths[ctype]
		if root == nil then return tbl end -- We can just save ourselves the work, nothing will be found
	end
	find_recursive(tbl, loader and loader.Paths, root, map, codename)
	return tbl
end


--[[-------------------------------------------------------------------------
Loading a Config
---------------------------------------------------------------------------]]
local config_convar = CreateConVar("nzu_nextconfig", "", {FCVAR_ARCHIVE}, "The active Config path that the server will load when the map has initialized.")

function nzu.LoadConfig(config, nocleanup, callback)
	if not config then ErrorNoHalt(string.format("[nzu_load] No Config found for '%s'", config.Codename)) return false end
	if not config.Map then ErrorNoHalt(string.format("[nzu_load] Could not determine the map for Config '%s'",config.Codename)) return false end -- Cannot load a map we don't know D:
	local loader = config_loaders[config.Format or ""]
	if not loader then ErrorNoHalt(string.format("[nzu_load] Config '%s' (%s) has Config Type '%s', but no Loader for that type exists!", config.Codename, config.Map, config.Format or "???")) return false end

	if config.Map ~= game.GetMap() then
		config_convar:SetString(config.Path)
		RunConsoleCommand("changelevel", config.Map)
		return -- Nil = We're switching map (do not do anything!)
	end

	-- First check if we can load this config
	local settings = loader.LoadSettings(config.Path)
	if not settings then ErrorNoHalt(string.format("[nzu_load] Could not load Config Settings data for '%s' (%s)[%s]", config.Codename, config.Map, config.Format)) return false end
	local map = loader.ReadMap(config.Path)
	if not map then ErrorNoHalt(string.format("[nzu_load] Could not load Config Map data for '%s' (%s)[%s]", config.Codename, config.Map, config.Format)) return false end

	hook.Run("nzu_PreConfigLoaded", config)

	local load_map = function()
		-- Load the settings

		-- Load the map, based on the loader's function (future for backwards compatibility :D)
		loader.LoadMap(map)

		-- Run post-load checkups
		hook.Run("nzu_PostConfigLoaded", config)
		nzu.CheckMismatch()
		if callback then callback() end
	end

	-- Run the function! If nocleanup is not specified, we will clean up the map first
	if nocleanup then load_map() else game.CleanUpMap(false, nil, load_map) end
	return true -- Keep in mind, that this will return before the map is actually loaded, if the map is set to clean up!
end

-- When the server has booted up, if this ConVar contains a value valid to this map, then
-- we will load this config automatically at the start
hook.Add("InitPostEntity", "nzu_AutoLoadConfig", function()
	local val = config_convar:GetString()
	if val and val ~= "" then
		local config = nzu.GetConfig(val)
		if IsValid(config) and config.Map == game.GetMap() then nzu.LoadConfig(config, true) end
	end
end)