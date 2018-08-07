
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

	function nzu.LoadMap(str)
		-- Mostly copied from gmsave module
		
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
			
			loadedents = {} -- Empty and prepare for new wave (should already be empty though)
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
			loadedents = {} -- Empty to clean up
			
			DisablePropCreateEffect = nil
		end)

	end

	function nzu.SaveMap()
		
	
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

		local json = util.TableToJSON(tab)
		if not json then ErrorNoHalt("nzu_saveload: Could not write JSON of config save!") return end
		
		
	end
end