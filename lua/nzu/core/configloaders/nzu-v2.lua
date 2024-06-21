local CONFIG = {}
CONFIG.Paths = {
	Official = "gamemodes/nzombies-unlimited/gamemode/officialconfigs/",
	Workshop = "lua/nzu/workshopconfigs/",
	Local = "data/nzu/localconfigs/",
}

-- Return true if a config (of this type!) exists at the given path, and with the given metadata
-- This base class can return true as long as the config.dat exists, but if another config type should ever inherit the same file paths,
-- these two MUST differentiate themselves with some difference here to ensure only the correct one is loaded!!
function CONFIG.Exists(path, metadata)
	return file.Exists(path.."/config.lua", "GAME") or file.Exists(path.."/config.dat", "GAME")
end

--[[-------------------------------------------------------------------------
Load Config Info

This essentially runs when a Config is retrieved from disk, which matches this format
Sometimes Codename and Type is not known due to being given only a path, so we can use this
place to fill it in
---------------------------------------------------------------------------]]
function CONFIG.LoadInfo(config, path)
	if not config.Codename or not config.Type then
		config.Codename = string.GetFileFromFilename(path) -- Folder name
		config.Type = "Unknown"

		local root = string.GetPathFromFilename(path)
		for k,v in pairs(CONFIG.Paths) do
			if root == v then
				config.Type = k
				break
			end
		end
	end
end


--[[-------------------------------------------------------------------------
Loading a Settings Map table. This includes initializing necessary Extensions
---------------------------------------------------------------------------]]
function CONFIG.LoadSettings(path)
	local _, settings = pcall(util.JSONToTable, file.Read(path.."/settings.lua", "GAME") or file.Read(path.."/settings.txt", "GAME"))
	-- TODO: Parse settings back to the original data structure (depending on how we do settings)
	-- Maybe also TODO: Make a default table in case the data couldn't be loaded, or wasn't found?
	return settings -- This could be nil
end



--[[-------------------------------------------------------------------------
Loading a packed Map table
---------------------------------------------------------------------------]]
function CONFIG.ReadMap(path)
	local _, map = pcall(util.JSONToTable, file.Read(path.."/config.lua", "GAME") or file.Read(path.."/config.dat", "GAME"))
	return map -- This could be nil
end

function CONFIG.LoadMap(data)
	-- Populate the Config with all module loaders
	if data.Modules then
		for k,v in pairs(data.Modules) do
			if file.Exists("nzu/core/modules/"..k.."/load.lua", "LUA") then
				local func = include("lua/nzu/core/modules/"..k.."/load.lua")
				func(v)
			else
				print("[nzu_load] Attempted to load non-existent Core module: "..k)
			end
		end
	end

	-- Load from Extensions that are enabled
	-- TODO

	-- Finally, load remaining entities
	if data.Map then
		DisablePropCreateEffect = true
		duplicator.RemoveMapCreatedEntities()
		duplicator.Paste(nil, data.Map.Entities, data.Map.Constraints)
		DisablePropCreateEffect = nil
	end
end

return CONFIG