
if SERVER then
	local savefuncs = {}
	local classfuncs = {}
	function nzu.AddSaveExtension(id, tbl)
		savefuncs[id] = tbl
		-- Table containing 2 functions: Save and Load
		-- Load is called with data returned by Save
		-- Save can return second argument a table of entities
		-- Then Load receives the recreated entities in a table as second argument
		
		-- Can optionally contain PreSave and PreLoad functions which do the same (but without entity support)
	end
	
	local loadedents = {}
	duplicator.RegisterEntityModifier("nzu_saveid", function(ply, ent, data)
		local id = data.id
		if not id then return end
		
		loadedents[id] = ent -- Doesn't actually modify the entity, just registers who it used to be
	end)

	local function loadmap(config)
		-- Mostly copied from gmsave module
		if not file.Exists(config.Path.."/config.dat", "GAME") then return end -- Not error, just load nothing
		local str = file.Read(config.Path.."/config.dat", "GAME")
		
		local startchar = string.find(str, '')
		if startchar ~= nil then
			str = string.sub(str, startchar)
		end
		
		str = str:reverse()
		local startchar = string.find(str, '')
		if startchar ~= nil then
			str = string.sub(str, startchar)
		end
		str = str:reverse()

		local tab = util.JSONToTable(str)

		if not istable(tab) then
			-- Error loading save!
			print("nzu_saveload: Couldn't decode config save from JSON!")
			return false
		end

		game.CleanUpMap()

		timer.Simple(0.1, function()
			DisablePropCreateEffect = true
			
			duplicator.RemoveMapCreatedEntities() -- Keep this? Maybe look for a way to reset map-created entities (like doors)
			duplicator.Paste(nil, tab.Entities, tab.Constraints)
			
			local loadedents = {} -- Empty and prepare for new wave (should already be empty though)
			for k,v in pairs(tab.SaveExtensions) do
				if savefuncs[k] then
					local data = v.Data
					local entities
					if v.Entities then
						entities = {}
						for k,v in pairs(v.Entities) do
							if loadedents[v] then -- Grab the pasted entities based on their index when they were saved
								entities[k] = loadedents[v]
							end
						end
					end
					savefuncs[k].Load(data, entities)
				else
					print("nzu_saveload: Attempted to load non-existent Save Extension: "..k.."!")
				end
			end
			--loadedents = {} -- Empty to clean up
			
			DisablePropCreateEffect = nil
		end)
	end
	
	function nzu.LoadConfig(config)
		if type(config) == "string" then config = nzu.GetConfig(config) end -- Compatibility with string arguments (codenames)

		if not config or not config.Codename or not config.Path or not config.Map then
			Error("nzu_saveload: Attempted to load invalid config.")
			return
		end

		if not nzu.CurrentConfig and config.Map == game.GetMap() then
			-- Allow immediate loading if no config has previously been loaded (default gamemode state)
			loadmap(config)
			nzu.CurrentConfig = config
			return
		end
		
		if config.Path == nzu.CurrentConfig.Path then --and NZU_SANDBOX then -- Should this only apply in Sandbox?
			-- Just clean up the map and refresh
			return
		end

		local worked = false
		for i = 1,5 do
			file.Write("nzombies-unlimited/config_to_load.txt", config.Path)
			timer.Simple(0.1, function()
				if file.Read("nzombies-unlimited/config_to_load.txt", "DATA") == config.Path then
					worked = true
				end
			end)
			if worked then break end
		end

		if not worked then
			print("nzu_saveload: Couldn't write config_to_load.txt after 5 attempts. Manually change the map and load the config again.")
			return
		end
		print("nzu_saveload: Changing map and loading config '"..config.Codename.."'...")
		RunConsoleCommand("changelevel", config.Map)
	end

	function nzu.UnloadConfig()
		if not nzu.CurrentConfig then
			print("nzu_saveload: No need to unload config with no config loaded.")
		return end
		
		local worked = false
		for i = 1,5 do
			file.Delete("nzombies-unlimited/config_to_load.txt")
			timer.Simple(0.1, function()
				if not file.Exists("nzombies-unlimited/config_to_load.txt", "DATA") then
					worked = true
				end
			end)
			if worked then break end
		end

		if not worked then
			print("nzu_saveload: Couldn't delete config_to_load.txt after 5 attempts. Manually delete the file and reload the map.")
			return
		end
		print("nzu_saveload: Changing map and unloading configs...")
		RunConsoleCommand("changelevel", game.GetMap())
	end

	if NZU_SANDBOX then -- Saving a map can only be done in Sandbox
		function nzu.SaveConfig()
			if not nzu.CurrentConfig then
				Error("nzu_saveload: No current config exists to save to.")
				return
			end

			local tbl = {}	
			local Ents = ents.GetAll()
			for k,v in pairs(Ents) do
				if not gmsave.ShouldSaveEntity(v, v:GetSaveTable()) or v:IsConstraint() then
					Ents[k] = nil
				else
					duplicator.StoreEntityModifier(v, "nzu_saveid", {id = k})
				end
			end
			tbl.Entities = duplicator.CopyEnts(Ents)
			
			tbl.SaveExtensions = {}
			for k,v in pairs(savefuncs) do
				local data, entities = v.Save()
				if data or entities then
					local save = {Data = data}
					if entities then
						save.Entities = {}
						for k2,v2 in pairs(entities) do
							table.insert(save.Entities, v2:EntIndex())
						end
					end
					tbl.SaveExtensions[k] = save
				end
			end

			local json = util.TableToJSON(tbl)
			if not json then Error("nzu_saveload: Could not write JSON of config save!") return end
			
			if not file.IsDir("nzombies-unlimited", "DATA") then file.CreateDir("nzombies-unlimited", "DATA") end
			if not file.IsDir("nzombies-unlimited/localconfigs", "DATA") then file.CreateDir("nzombies-unlimited/localconfigs", "DATA") end
			if not file.IsDir("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename, "DATA") then file.CreateDir("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename, "DATA") end

			file.Write("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/config.dat", json)
			file.Write("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/info.txt", util.TableToKeyValues(nzu.CurrentConfig.Info))
		end
	end

	function nzu.GetConfigFromFolder(path, s)
		if file.IsDir(path, s) then
			local codename = string.match(path, ".+/(.+)")
			if not codename then
				print("nzu_saveload: Could not get config codename from path: "..path)
			return end

			local worked, info = pcall(util.KeyValuesToTable, file.Read(path.."/info.txt", s))
			if not worked then
				print("nzu_saveload: Malformed info.txt from config '"..codename.."':\n"..info)
				-- This should return nothing! It follows that the game also can't determine the map this config is played on!
			return end

			if not info.Map then
				print("nzu_saveload: No map found for config '"..codename.."'")
			return end

			local config = {}
			config.Codename = codename
			config.Map = info.Map
			info.Map = nil
			config.Info = info

			config.Path = (s == "LUA" and "lua/" or s == "DATA" and "data/" or "")..path

			if config.Path == "gamemodes/nzombies-unlimited/officialconfigs/"..codename then
				config.Type = "Official"
				--config.Path = path
			elseif config.Path == "lua/nzombies-unlimited/workshopconfigs/"..codename then -- Replace when workshop config integration
				config.Type = "Workshop"
				--config.Path = "lua/"..path
			elseif config.Path == "data/nzombies-unlimited/localconfigs/"..codename then
				config.Type = "Local"
				--config.Path = "data/"..path
			else
				config.Type = "Unknown"
				--config.Path = path
			end

			return config
		end
	end
	function nzu.GetOfficialConfig(f)
		return nzu.GetConfigFromFolder("gamemodes/nzombies-unlimited/officialconfigs/"..f, "GAME")
	end
	function nzu.GetLocalConfig(f)
		return nzu.GetConfigFromFolder("nzombies-unlimited/localconfigs/"..f, "DATA")
	end
	function nzu.GetWorkshopConfig(f)
		return nzu.GetConfigFromFolder("nzombies-unlimited/workshopconfigs/"..f, "LUA")
	end

	function nzu.GetConfig(f)
		-- Determines an order if configs should have the same name
		return nzu.GetOfficialConfig(f) or nzu.GetLocalConfig(f) or nzu.GetWorkshopConfig(f)
	end

	function nzu.GetConfigs()
		local configs = {Official = {}, Local = {}, Workshop = {}}

		-- Official configs
		local _,dirs = file.Find("gamemodes/nzombies-unlimited/officialconfigs/*", "GAME")
		for k,v in pairs(dirs) do
			local config = nzu.GetOfficialConfig(v)
			if config then table.insert(configs.Official, config) end
		end

		-- Local configs
		local _,dirs = file.Find("nzombies-unlimited/localconfigs/*", "DATA")
		for k,v in pairs(dirs) do
			local config = nzu.GetLocalConfig(v)
			if config then table.insert(configs.Local, config) end
		end

		-- Workshop configs
		local _,dirs = file.Find("nzombies-unlimited/workshopconfigs/*", "LUA")
		for k,v in pairs(dirs) do
			local config = nzu.GetWorkshopConfig(v)
			if config then table.insert(configs.Workshop, config) end
		end

		return configs
	end
end