
-- This file is SERVER only
local navdoors

-- Load in the data. We'll need to process it, as it is not pure data
nzu.AddSaveExtension("NavLocks", {
	Load = function(data)
		navmesh.Load()
		navdoors = {}

		if navmesh.GetNavAreaCount() ~= data.Count then
			PrintMessage(HUD_PRINTTALK, "Warning: The map appears to have a different Navmesh from the last save of this Config. This could interfere with Navlocks. Return to Sandbox and edit it if necessary.")
		end

		for k,v in pairs(navmesh.GetAllNavAreas()) do
			local id = v:GetID()
			if data.NavBlocks[id] then
				-- Just disconnect all outgoing connections
				for k2,v2 in pairs(v:GetAdjacentAreas()) do
					v:Disconnect(v2)
				end
			elseif data.NavDoors[id] then
				local group = data.NavDoors[id]
				if not navdoors[group] then navdoors[group] = {} end

				-- Disconnect but store which we were previously connected to
				local tbl = {}
				for k2,v2 in pairs(v:GetAdjacentAreas()) do
					v:Disconnect(v2)
					table.insert(tbl, v2)
				end

				table.insert(navdoors[group], {Area = v, Connections = tbl})
			end
		end
	end
})

-- Simply reconnect them when that group is opened! :D
hook.Add("nzu_DoorGroupOpened", "nzu_NavLock_OpenLocks", function(id, ply)
	if navdoors and navdoors[id] then
		for k,v in pairs(navdoors[id]) do
			if IsValid(v.Area) then
				for k2,v2 in pairs(v.Connections) do
					v.Area:ConnectTo(v2)
				end
			end
		end
	end
end)

-- I really wanted to block nav_save as it can cause irreparable damage if called during the gamemode due to the changes it makes :/
-- It doesn't seem possible to block engine commands though
-- I just hope people will be smart enough to not nav_save mid-game, especially not on servers