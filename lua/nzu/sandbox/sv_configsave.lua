--[[-------------------------------------------------------------------------
SAVING FUNCTIONS - SANDBOX ONLY
---------------------------------------------------------------------------]]
local latest_format = nzu.LatestConfigFormat
local savepath = string.sub(nzu.GetConfigLoader(latest_format).Paths.Local, 6) -- string.sub to remove the "data/" part of it
local configexists = nzu.GetConfigLoader(latest_format).Exists

function nzu.MakeConfigLocal(new_codename)
	local config = nzu.CurrentConfig
	if not config then return false end

	new_codename = new_codename or config.Codename
	local new_path = "data/"..savepath.."/"..new_codename
	if new_path ~= config.Path and configexists(new_path) then return false end -- Can't do it if another one already exists by this name

	config.Type = "Local"
	config.Path = new_path
	config.Codename = new_codename
	return true
end

--[[-------------------------------------------------------------------------
Making a new Config!
---------------------------------------------------------------------------]]
function nzu.NewConfig(codename)
	local map = game.GetMap()
	local path = "data/"..savepath..map.."/"..codename
	if configexists(path) then return end

	local config = {
		Type = "Local",
		Codename = codename,
		Map = map,
		Path = path,
		Format = latest_format,
	}
	return config	
end

--[[-------------------------------------------------------------------------
Packing a Map table
---------------------------------------------------------------------------]]
local function packmap()
	local data = {}

	-- Save all core modules
	data.Modules = {}
	local _,modules = file.Find("nzu/core/modules/*", "LUA")
	for k,v in pairs(modules) do
		if file.Exists("nzu/core/modules/"..v.."/save.lua", "LUA") then
			local func = include("lua/nzu/core/modules/"..v.."/save.lua")
			data.Modules[v] = func()
		end
	end
	
	-- Save all Extensions
	-- TODO

	-- Save all Entities that were not ignored by nzu.IgnoreSaveEntity
	local map = {Entities = {}, Constraints = {}}
	for k,v in pairs(ents.GetAll()) do
		if v.nzu_SaveIgnore or not gmsave.ShouldSaveEntity(v, v:GetSaveTable()) or v:IsConstraint() then
			v.nzu_SaveIgnore = nil
		else
			map = duplicator.Copy(v, map)
		end
	end
	data.Map = map

	return util.TableToJSON(data)
end

--[[-------------------------------------------------------------------------
Packing settings
---------------------------------------------------------------------------]]
local function packsettings()
	-- TODO
	local tbl = {}
	return util.TableToJSON(tbl, true)
end


--[[-------------------------------------------------------------------------
Saving functions
---------------------------------------------------------------------------]]

-- Any time any config attempts to save, we convert it to a latest version if we can!
local function check_latest_local(config)
	if config.Type == "Local" and config.Format == latest_format then return end -- If we're already local and newest, we can just return nil
	if nzu.MakeConfigLocal() then -- Make the current config Local and of the latest format (and return whether that was successful)
		config.Format = latest_format -- Upgrade to latest format
		return true -- Upgraded
	end
	return false -- Can't upgrade
end

local function check_dir(path)
	if not file.IsDir(path, "DATA") then
		file.CreateDir(path)
	end
end

local function save_meta(config) file.Write(savepath..config.Codename.."/info.txt", util.TableToJSON(nzu.GetConfigMetadata(config), true)) end
local function save_settings(config) file.Write(savepath..config.Codename.."/settings.txt", packsettings()) end
local function save_map(config) file.Write(savepath..config.Codename.."/config.dat", packmap()) end

-- You can choose to save individually, or save everything
function nzu.SaveConfigMetadata()
	local config = nzu.CurrentConfig
	if not config then return end
	local status = check_latest_local(config)
	if status == false then return false end
	
	check_dir(savepath..config.Codename)
	save_meta(config)
	return status
end

function nzu.SaveConfigSettings()
	local config = nzu.CurrentConfig
	if not config then return end
	local status = check_latest_local(config)
	if status == false then return false end
	
	check_dir(savepath..config.Codename)
	save_settings(config)
	return status
end

function nzu.SaveConfigMap()
	local config = nzu.CurrentConfig
	if not config then return end
	local status = check_latest_local(config)
	if status == false then return false end
	
	check_dir(savepath..config.Codename)
	save_map(config)
	return status
end

function nzu.SaveConfig()
	local config = nzu.CurrentConfig
	if not config then return end
	local status = check_latest_local(config)
	if status == false then return false end

	check_dir(savepath..config.Codename)
	save_meta(config)
	save_settings(config)
	save_map(config)
	return status
end