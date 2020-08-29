local savefuncs = {}
local classfuncs = {}
function nzu.AddSaveExtension(id, tbl)
	savefuncs[id] = tbl
	-- Table containing 2 functions: Save and Load
	-- Load is called with data returned by Save
	-- Save can return second argument a table of entities
	-- Then Load receives the recreated entities in a table as second argument
	
	-- Can optionally contain PreSave and PreLoad functions which do the same (but without entity support)
	-- Also PostSave and PostLoad
end

local loadedents
duplicator.RegisterEntityModifier("nzu_saveid", function(ply, ent, data)
	local id = data.id
	if not id then return end
	
	if loadedents then loadedents[id] = ent end -- Doesn't actually modify the entity, just registers who it used to be
end)

function nzu.ReloadConfigMap(config)
	local config = config or nzu.CurrentConfig
	if not config then return end
	
	local str = file.Read(config.Path.."/config.lua", "GAME") or file.Read(config.Path.."/config.dat", "GAME")
	if not str then return end -- Not error, just load nothing
	
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

	game.CleanUpMap()
	if not istable(tab) then
		-- Error loading save!
		print("nzu_saveload: Couldn't decode config save from JSON!")
		return false
	end

	timer.Simple(0.1, function()
		navmesh.Load()
	
		-- Do preloads
		for k,v in pairs(tab.SaveExtensions) do
			if savefuncs[k] and savefuncs[k].PreLoad then
				savefuncs[k].PreLoad(v.PreSave)
			end
		end

		DisablePropCreateEffect = true

		loadedents = {} -- Empty and prepare for new wave (should already be empty though)
		
		duplicator.RemoveMapCreatedEntities() -- Keep this? Maybe look for a way to reset map-created entities (like doors)
		duplicator.Paste(nil, tab.Map.Entities, tab.Map.Constraints)
		
		local postloads = {}
		for k,v in pairs(tab.SaveExtensions) do
			if savefuncs[k] then
				local data = v.Save and v.Save.Data
				local entities
				if v.Save and v.Save.Entities then
					entities = {}
					for k,v in pairs(v.Save.Entities) do
						if loadedents[v] then -- Grab the pasted entities based on their index when they were saved
							entities[k] = loadedents[v]
						end
					end
				end
				if savefuncs[k].Load then savefuncs[k].Load(data, entities) end

				if savefuncs[k].PostLoad then table.insert(postloads, savefuncs[k].PostLoad) end
			else
				print("nzu_saveload: Attempted to load non-existent Save Extension: "..k.."!")
			end
		end
		loadedents = nil -- Clean up
		
		DisablePropCreateEffect = nil

		-- Post load
		for k,v in pairs(postloads) do
			v(tab.SaveExtensions[k].PostSave)
		end
		
		hook.Run("nzu_PostConfigMap", config)
	end)
end

local function loadconfig(config)
	hook.Run("nzu_PreLoadConfig", config)

	-- 1) Load Extensions
	local str = file.Read(config.Path.."/settings.txt", "GAME") or file.Read(config.Path.."/settings.lua", "GAME")
	if str then
		local tbl = util.JSONToTable(str)
		if tbl then
			for k,v in pairs(tbl) do
				-- Load extensions with specified settings (rather than defaults)
				-- These are loaded in the order they were saved (unless the .txt was modified)

				local ext = nzu.GetExtension(string.lower(v.ID))
				if ext then
					ext:BulkSetSettings(v.Settings)
				else
					nzu.LoadExtension(id, v.Settings)
				end
			end
		end
	end

	-- 2) Load Map + Save Extensions
	-- Mostly copied from gmsave module
	nzu.ReloadConfigMap(config)

	hook.Run("nzu_PostLoadConfig", config)
end

local function getplystonetworkto()
	local plys = {}
	for k,v in pairs(player.GetAll()) do
		if nzu.IsAdmin(v) and v.nzu_ConfigsRequested then
			table.insert(plys, v)
		end
	end
	return plys
end






--[[-------------------------------------------------------------------------
Networking of Configs
---------------------------------------------------------------------------]]
util.AddNetworkString("nzu_saveconfig") -- SERVER: Update clients' config cache || CLIENT: Request a config save
util.AddNetworkString("nzu_configsnetworked") -- SERVER: Tell client request received || CLIENT: Request full list of configs for cache
util.AddNetworkString("nzu_deleteconfig") -- SERVER: Remove from clients' config cache || CLIENT: Request config deletion
util.AddNetworkString("nzu_saveconfig_settings") -- CLIENT: Request a save of the config's settings

local function networkconfig(config, ply, loaded)
	net.Start("nzu_saveconfig")
		net.WriteString(config.Type)
		net.WriteString(config.Codename)
		net.WriteString(config.Name)
		net.WriteString(config.Map)
		net.WriteString(config.Authors or "")
		net.WriteString(config.Description or "")
		net.WriteString(config.WorkshopID or "")

		-- Send list of required addons
		local num = config.RequiredAddons and table.Count(config.RequiredAddons) or 0
		net.WriteUInt(num, 8) -- I don't expect more than 255 addons for a simple config
		if num > 0 then
			for k,v in pairs(config.RequiredAddons) do
				net.WriteString(k)
				net.WriteString(v)
			end
		end
		-- Extensions and Path need not be networked, only server needs to know that

		net.WriteBool(loaded) -- Tells clients this is the current config
	net.Send(ply)
end

local function unnetwork(config)
	net.Start("nzu_deleteconfig")
		net.WriteString(config.Type)
		net.WriteString(config.Codename)
	net.Broadcast()
end

-- Client requesting config list
net.Receive("nzu_configsnetworked", function(len, ply)
	if nzu.IsAdmin(ply) then -- Only admins can access config lists
		if not ply.nzu_ConfigsRequested then
			ply.nzu_ConfigsRequested = true -- From now on, network to this player whenever a config is saved/updated
			net.Start("nzu_configsnetworked")
				net.WriteBool(true)
			net.Send(ply)

			for k,v in pairs(nzu.GetConfigs()) do
				for k2,v2 in pairs(v) do
					networkconfig(v2, ply)
				end
			end
		end
	end
end)

local dontnetwork = false
hook.Add("nzu_ConfigInfoSaved", "nzu_NetworkUpdatedConfigs", function(config)
	if dontnetwork then return end
	networkconfig(config, config == nzu.CurrentConfig and player.GetAll() or getplystonetworkto()) -- Network this updated config to all players
end)










--[[-------------------------------------------------------------------------
Loading a Config
---------------------------------------------------------------------------]]
util.AddNetworkString("nzu_loadconfig") -- SERVER: Load a config || CLIENT: Receive list of missing addons

function nzu.LoadConfig(config, ctype, mode)
	if type(config) == "string" then config = nzu.GetConfig(config, ctype) end -- Compatibility with string arguments (codenames)

	if not config or not config.Codename or not config.Path or not config.Map then
		Error("nzu_saveload: Attempted to load invalid config.")
		return
	end

	if not nzu.CurrentConfig and config.Map == game.GetMap() and mode ~= false then
		-- Allow immediate loading if no config has previously been loaded (default gamemode state)
		nzu.CurrentConfig = config
		loadconfig(config)
		networkconfig(config, player.GetAll(), true)
		hook.Run("nzu_ConfigLoaded", config)
		return
	end

	timer.Create("nzu_saveload", 0.25, 5, function()
		file.Write("nzombies-unlimited/config_to_load.txt", config.Path)
		if file.Read("nzombies-unlimited/config_to_load.txt", "DATA") == config.Path then

			print("nzu_saveload: Changing map and loading config '"..config.Codename.."'...")
			timer.Destroy("nzu_saveload")

			if mode == false then -- Pass the mode you want to play in - i.e. nzu.LoadConfig(config, nil, NZU_NZOMBIES) to load in nZombies (it'll be false in Sandbox, thus changing mode here)
				if NZU_NZOMBIES then RunConsoleCommand("nzu_sandbox_enable", "1") end
				RunConsoleCommand("gamemode", NZU_NZOMBIES and "sandbox" or "nzombies-unlimited")
			end
			RunConsoleCommand("changelevel", config.Map)
		end
	end)
	print("nzu_saveload: Couldn't write config_to_load.txt after 5 attempts. Manually change the map and load the config again.")
end

function nzu.LoadGamemode(mode)
	if not mode then
		if NZU_NZOMBIES then RunConsoleCommand("nzu_sandbox_enable", "1") end
		RunConsoleCommand("gamemode", NZU_NZOMBIES and "sandbox" or "nzombies-unlimited")
		RunConsoleCommand("changelevel", game.GetMap())
	end
end

function nzu.UnloadConfig()
	if not nzu.CurrentConfig then
		print("nzu_saveload: No need to unload config with no config loaded.")
	return end
	
	local worked = false
	timer.Create("nzu_saveload", 0.25, 5, function()
		file.Delete("nzombies-unlimited/config_to_load.txt")
		if not file.Exists("nzombies-unlimited/config_to_load.txt", "DATA") then

			timer.Destroy("nzu_saveload")
			print("nzu_saveload: Changing map and unloading configs...")
			RunConsoleCommand("changelevel", game.GetMap())
		end
	end)

	print("nzu_saveload: Couldn't delete config_to_load.txt after 5 attempts. Manually delete the file and reload the map.")
end

net.Receive("nzu_loadconfig", function(len, ply)
	if not nzu.IsAdmin(ply) then return end -- Of course servers need to check too!

	if net.ReadBool() then -- Load a config
		local codename = net.ReadString()
		local ctype = net.ReadString()
		local config = nzu.GetConfig(codename, ctype)
		if not config then
			print("nzu_saveload: Client attempted to load to a non-existing config.", ply, codename, type)
		return end

		if not net.ReadBool() then --and config.RequiredAddons then
			local c_addons = table.Copy(config.RequiredAddons)
			if c_addons then
				local addons = engine.GetAddons()
				for k,v in pairs(addons) do
					if v.mounted and v.wsid then
						c_addons[tonumber(v.wsid)] = nil
					end
				end

				-- Some uninstalled addons are found!
				local num = table.Count(c_addons)
				if num > 0 then
					net.Start("nzu_loadconfig")
						net.WriteString(config.Codename)
						net.WriteString(config.Type)

						net.WriteUInt(num, 8)
						for k,v in pairs(c_addons) do
							net.WriteString(k)
							net.WriteString(v)
						end
					net.Send(ply)
					return
				end
			end
		end
		
		nzu.LoadConfig(config)
	else -- Unload!
		nzu.UnloadConfig()
	end
end)




--[[-------------------------------------------------------------------------
Edit/Play loading by switching modes
---------------------------------------------------------------------------]]
util.AddNetworkString("nzu_loadconfig_mode")
net.Receive("nzu_loadconfig_mode", function(len, ply)
	if not nzu.IsAdmin(ply) then return end -- Still only admins!

	if net.ReadBool() then
		local codename = net.ReadString()
		local ctype = net.ReadString()
		local config = nzu.GetConfig(codename, ctype)
		if not config then
			print("nzu_saveload: Client attempted to load to a non-existing config.", ply, codename, type)
		return end

		nzu.LoadConfig(config, nil, false) -- When it's false, it will think it's always the opposite mode
	else
		nzu.LoadGamemode(false)
	end
end)











--[[-------------------------------------------------------------------------
Server reboot Config management
---------------------------------------------------------------------------]]
hook.Add("Initialize", "nzu_InitializeConfig", function()
	local path = file.Read("nzombies-unlimited/config_to_load.txt", "DATA")
	print("LOADING:", path)
	if path then
		local config = nzu.GetConfigFromFolder(path)
		print("CONFIG:", config)
		if config then nzu.LoadConfig(config) end
	end

	file.Delete("nzombies-unlimited/config_to_load.txt")
end)

-- When players join, network to them the currently loaded config
hook.Add("PlayerInitialSpawn", "nzu_CurrentConfig", function(ply)
	if nzu.CurrentConfig then
		networkconfig(nzu.CurrentConfig, ply, true)
	end
end)












--[[-------------------------------------------------------------------------
Sandbox saving of Configs
---------------------------------------------------------------------------]]

if NZU_SANDBOX then -- Saving a map can only be done in Sandbox
	function nzu.IgnoreSaveEntity(ent)
		ent.nzu_SaveIgnore = true
	end

	local ignoredfields = {}
	function nzu.IgnoreSaveField(key)
		ignoredfields[key] = true
	end

	local ENTITY = FindMetaTable("Entity")
	function ENTITY:IgnoreField(key)
		if not self.nzu_IgnoredFields then self.nzu_IgnoredFields = {} end
		self.nzu_IgnoredFields[key] = true
	end

	local function getmapjson()
		local tbl = {}
		tbl.SaveExtensions = {}

		for k,v in pairs(savefuncs) do
			tbl.SaveExtensions[k] = {} -- Prepare Save Extension table. Even if it's empty, it tells the Config to attempt to load these functions on load.

			if v.PreSave then
				local data = v.PreSave()
				if data then
					tbl.SaveExtensions[k].PreSave = data
				end
			end
		end


		local Ents = ents.GetAll()
		local map = {Entities = {}, Constraints = {}}
		for k,v in pairs(Ents) do
			if v.nzu_SaveIgnore or not gmsave.ShouldSaveEntity(v, v:GetSaveTable()) or v:IsConstraint() then
				v.nzu_SaveIgnore = nil
			else
				duplicator.StoreEntityModifier(v, "nzu_saveid", {id = v:EntIndex()})

				local temp = {}
				for k2,v2 in pairs(ignoredfields) do
					if v[k2] then
						temp[k2] = v[k2]
						v[k2] = nil
					end
				end

				if v.nzu_IgnoredFields then
					for k2,v2 in pairs(v.nzu_IgnoredFields) do
						temp[k2] = v[k2]
						v[k2] = nil
					end
					temp.nzu_IgnoredFields = v.nzu_IgnoredFields
					v.nzu_IgnoredFields = nil
				end

				map = duplicator.Copy(v, map)
				for k2,v2 in pairs(temp) do
					v[k2] = v2
				end
			end
		end
		tbl.Map = map
		
		local postsaves = {}
		for k,v in pairs(savefuncs) do
			if v.Save then
				local data, entities = v.Save()
				if data or entities then
					local save = {Data = data}
					if entities then
						save.Entities = {}
						for k2,v2 in pairs(entities) do
							table.insert(save.Entities, v2:EntIndex())
						end
					end
					tbl.SaveExtensions[k].Save = save
				end
			end

			if v.PostSave then table.insert(postsaves, v.PostSave) end
		end

		-- Post save
		for k,v in pairs(postsaves) do
			local data = v()
			if data then
				tbl.SaveExtensions[k].PostSave = data
			end
		end

		return util.TableToJSON(tbl)
	end

	local function getmetadata()
		-- Save metadata
		return util.TableToJSON({
			name = nzu.CurrentConfig.Name,
			map = nzu.CurrentConfig.Map,
			authors = nzu.CurrentConfig.Authors,
			description = nzu.CurrentConfig.Description,
			workshopid = nzu.CurrentConfig.WorkshopID,
			requiredaddons = nzu.CurrentConfig.RequiredAddons
		}, true)
	end

	local loadparse = {
		[TYPE_COLOR] = function(v)
			return Color(v.r, v.g, v.b, v.a)
		end,
	}
	local function getextensionsettings()
		local tbl = {}
		for k,v in pairs(nzu.GetLoadedExtensions()) do
			if v.Settings then
				local t = {}
				-- Loop through the settings meta; If any have a "Save" we will save the value of that function instead
				for k2,v2 in pairs(v.Settings) do
					local tosave = v[k2]
					if v2.Save then tosave = v2.Save(tosave) end
					t[k2] = tosave
				end
				table.insert(tbl, {ID = k, Settings = t})
			else
				table.insert(tbl, {ID = k})
			end
		end
		return util.TableToJSON(tbl, true)
	end

	local function checkdirs()
		if not file.IsDir("nzombies-unlimited", "DATA") then file.CreateDir("nzombies-unlimited", "DATA") end
		if not file.IsDir("nzombies-unlimited/localconfigs", "DATA") then file.CreateDir("nzombies-unlimited/localconfigs", "DATA") end
		if not file.IsDir("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename, "DATA") then file.CreateDir("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename, "DATA") end
	end

	function nzu.SaveConfigMap()
		if not nzu.CurrentConfig then
			Error("nzu_saveload: No current config exists to save to.")
			return
		end

		local json = getmapjson()
		if not json then Error("nzu_saveload: Could not write JSON of config save!") return end
		
		checkdirs()

		file.Write("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/config.dat", json)
		file.Write("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/info.txt", getmetadata())
		file.Write("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/settings.txt", getextensionsettings())

		--hook.Run("nzu_ConfigSaved", nzu.CurrentConfig) -- This isn't used yet (?)
		hook.Run("nzu_ConfigMapSaved", nzu.CurrentConfig)
	end

	-- Just in case you only want to write to the metadata or settings files
	function nzu.SaveConfigInfo()
		if not nzu.CurrentConfig then
			Error("nzu_saveload: No current config exists to save to.")
			return
		end		
		checkdirs()
		file.Write("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/info.txt", getmetadata())

		hook.Run("nzu_ConfigInfoSaved", nzu.CurrentConfig)
	end
	function nzu.SaveConfigSettings()
		if not nzu.CurrentConfig then
			Error("nzu_saveload: No current config exists to save to.")
			return
		end		
		checkdirs()
		file.Write("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/settings.txt", getextensionsettings())

		hook.Run("nzu_ConfigSettingsSaved", nzu.CurrentConfig)
	end

	function nzu.SaveConfig()
		nzu.SaveConfigMap()
		nzu.SaveConfigSettings()
		nzu.SaveConfigInfo()
		hook.Run("nzu_ConfigSaved", nzu.CurrentConfig)
	end

	-- Receiving client requests
	net.Receive("nzu_saveconfig", function(len, ply)
		if not nzu.IsAdmin(ply) then return end -- Of course servers need to check too!

		local codename = net.ReadString()
		if nzu.ConfigExists(codename, "Local") and (not nzu.CurrentConfig or nzu.CurrentConfig.Type ~= "Local" or nzu.CurrentConfig.Codename ~= codename) then
			print("nzu_saveload: Client attempted to save to an existing config without it being loaded first.", ply, codename)
		return end

		local config -- What we're saving to
		local tonetwork
		if nzu.CurrentConfig and nzu.CurrentConfig.Type == "Local" then -- We already have a local config loaded: Save to that
			config = nzu.CurrentConfig
		else
			-- We're saving a new config; Either new local, or new local copy of the one loaded
			config = {}
			config.Codename = codename
			config.Type = "Local"
			config.Path = nzu.GetConfigDir("Local")..codename

			nzu.CurrentConfig = config
			tonetwork = true
		end

		config.Name = net.ReadString()
		config.Map = game.GetMap()
		config.Authors = net.ReadString()
		config.Description = net.ReadString()
		local wid = net.ReadString()
		config.WorkshopID = wid ~= "" and wid or nil

		local numaddons = net.ReadUInt(8)
		config.RequiredAddons = {}
		for i = 1,numaddons do
			local id = net.ReadString()
			local name = net.ReadString()
			config.RequiredAddons[id] = name
		end

		if net.ReadBool() then
			-- Save the map, settings, and all!
			nzu.SaveConfigMap()
		end

		if tonetwork then
			dontnetwork = true -- We want to network manually
		end
		nzu.SaveConfigSettings()
		nzu.SaveConfigInfo() -- This triggers a networking
		if tonetwork then
			networkconfig(nzu.CurrentConfig, player.GetAll(), true)
			dontnetwork = false
			hook.Run("nzu_ConfigLoaded", config)
		end
	end)

	net.Receive("nzu_saveconfig_settings", function(len, ply)
		if not nzu.IsAdmin(ply) then return end
		nzu.SaveConfigSettings()
	end)














	--[[-------------------------------------------------------------------------
	Deleting a Config - Sandbox only
	---------------------------------------------------------------------------]]
	function nzu.DeleteConfig(config)
		if type(config) == "string" then config = nzu.GetConfig(config, "Local") end -- Compatibility with string arguments (codenames)

		local path = config and string.match(config.Path, "data/(.+)")
		if not path then
			Error("nzu_saveload: Attempted to delete non-existing or non-Local config.")
			return
		end

		local f = file.Find(path.."/*", "DATA")
		for k,v in pairs(f) do
			file.Delete(path.."/"..v)
		end
		file.Delete(path)

		unnetwork(config)

		hook.Run("nzu_ConfigDeleted", config)
		print("nzu_saveload: Successfully deleted Config: "..path)

		if nzu.CurrentConfig and config.Path == nzu.CurrentConfig.Path then
			nzu.UnloadConfig()
		end
	end

	net.Receive("nzu_deleteconfig", function(len, ply)
		if not nzu.IsAdmin(ply) then return end -- Of course only admins can delete folders and files!!
		nzu.DeleteConfig(net.ReadString())
	end)
end



--[[-------------------------------------------------------------------------
Additional Config folder file read/write
---------------------------------------------------------------------------]]
function nzu.WriteConfigFile(name, str)
	if nzu.CurrentConfig and nzu.CurrentConfig.Type == "Local" then
		file.Write("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/"..name..".txt", str)
		return true
	end
	return false
end

function nzu.ReadConfigFile(name)
	if nzu.CurrentConfig then
		return file.Read(nzu.CurrentConfig.Path.."/"..name..".lua", "GAME") or file.Read(nzu.CurrentConfig.Path.."/"..name..".txt", "GAME")
	end
end



-- Fixing up loading in nZombies
if NZU_NZOMBIES then
	duplicator.Allow("prop_physics")
	duplicator.Allow("prop_physics_multiplayer")
	duplicator.Allow("prop_effect")
end