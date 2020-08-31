--[[-------------------------------------------------------------------------
Nav Playable Area Analyzing
---------------------------------------------------------------------------]]

local function analyze()
	local navdoors, navblocks = nzu.GetNavLocks()

	-- Step 0
	-- Local functions for whether a navmesh is fully blocking, edge of room, or door
	local function navmesh_traversible(from_id, from_area, to_id, to_area)
		return not navblocks[to_id] and to_area:IsConnected(from_area)
	end

	local barricades = {}
	local function navmesh_playertraversible(from_id, from_area, to_id, to_area)
		return not barricades[to_id] and from_area:ComputeAdjacentConnectionHeightChange(to_area) < 60 -- Crouch jump height is 56 units
	end

	-- Step 1
	-- Find every barricade's navmeshes in order to be able to define edges on these meshes
	for k,v in pairs(ents.FindByClass("nzu_barricade")) do
		local area = navmesh.GetNavArea(v:GetPos(), 32)
		if IsValid(area) then
			barricades[area:GetID()] = area
		end
	end

	-- Step 2
	-- Prepare all seeds for where to begin rooms. These are all player spawnpoints, and adjacent areas to doors
	-- Doorconnects is the table that directs each group to a list of nav-id's
	local seeds = {}
	local doorconnects = {}

	-- Player spawnpoints
	for k,v in pairs(ents.FindByClass("nzu_spawnpoint")) do
		if v.SpawnpointType == "player" then
			local area = navmesh.GetNavArea(v:GetPos(), 10)
			if IsValid(area) then
				seeds[area:GetID()] = area
			end
		end
	end

	-- Doors. These need to also set up a reference list for the group
	for k,v in pairs(navdoors) do
		local area = navmesh.GetNavAreaByID(k)
		if IsValid(area) then
			for k2,v2 in pairs(area:GetAdjacentAreas()) do
				local id = v2:GetID()
				if not navdoors[id] and not navblocks[id] then
					seeds[id] = v2
					if not doorconnects[v] then doorconnects[v] = {} end
					doorconnects[v][id] = true -- Save that we have this connection in this group
				end
			end
		end
	end

	-- Step 3
	-- Initialize tables and containers, as well as room index
	local roomindex = 0
	local inmaps = {}
	local edgeseeds

	-- Step 4
	-- Go through all seeds and generate rooms if they haven't already been generated here
	for k,v in pairs(seeds) do
		if not inmaps[k] then
			roomindex = roomindex + 1

			local stack = {}
			local area = v

			while area ~= nil do
				local id = area:GetID()
				if not inmaps[id] then
					inmaps[id] = roomindex
					for k2,v2 in pairs(area:GetAdjacentAreas()) do
						local id2 = v2:GetID()
						if not navdoors[id2] and navmesh_traversible(id, area, id2, v2) then
							if navmesh_playertraversible(id, area, id2, v2) then
								table.insert(stack, v2)
							else
								if not edgeseeds then edgeseeds = {} end
								edgeseeds[id2] = v2
							end
						end
					end

					for k2,v2 in pairs(area:GetIncomingConnections()) do
						local id2 = v2:GetID()
						if not edgeseeds then edgeseeds = {} end
						edgeseeds[id2] = v2
					end
				end

				area = table.remove(stack)
			end
		end
	end

	-- Step 5
	-- Go through each door connection and apply the table of connections to these areas
	for k,v in pairs(doorconnects) do
		local t = {}
		for k2,v2 in pairs(v) do
			local room = inmaps[k2]
			if room then t[room] = true end
		end
		doorconnects[k] = t -- Replace the door connects with just this table
	end

	for k,v in pairs(navdoors) do
		local area = navmesh.GetNavAreaByID(k)
		if IsValid(area) then
			inmaps[area:GetID()] = doorconnects[v]
		end
	end

	-- Step 6
	-- Use Edge Seeds to discover all areas which may access rooms
	-- These are typically barricade spawn areas, but may also be one-way incoming connections
	-- This is needed so that spawnpoints out here can still belong to the room(s)
	local outmaps = {}

	while edgeseeds ~= nil do
		local newseeds
		for k,v in pairs(edgeseeds) do
			local ids = {}
			local stack = {}
			local area = v

			while area ~= nil do
				local id = area:GetID()
				local room = inmaps[id] or outmaps[id]
				if room then
					if room ~= ids then
						if type(room) == "table" then
							for k,v in pairs(room) do
								ids[k] = true
							end
						else
							ids[room] = true
						end
					end
				else
					outmaps[id] = ids
					for k2,v2 in pairs(area:GetAdjacentAreas()) do
						local id2 = v2:GetID()
						if not outmaps[id2] and navmesh_traversible(id, area, id2, v2) then
							table.insert(stack, v2)
						end
					end

					for k2,v2 in pairs(area:GetIncomingConnections()) do
						local id2 = v2:GetID()
						if not newseeds then newseeds = {} end
						newseeds[id2] = v2
					end
				end

				area = table.remove(stack)
			end
		end

		edgeseeds = newseeds
	end

	return inmaps, outmaps
end

--[[-------------------------------------------------------------------------
Tool
---------------------------------------------------------------------------]]
if NZU_NZOMBIES then return end

local TOOL = {}
TOOL.Category = "Navigation"
TOOL.Name = "#tool.nzu_tool_navrooms.name"

TOOL.nzu_NavEdit = true

TOOL.ClientConVar = {
	["room"] = "",
}

-- Enable nav_edit on deploy, only if admin or it's not already enabled
function TOOL:Deploy()
	if SERVER and not GetConVar("nav_edit"):GetBool() then
		if nzu.IsAdmin(self:GetOwner()) then
			RunConsoleCommand("nav_edit", "1")
		else
			self:GetOwner():ChatPrint("You can only use this tool while nav_edit is set to 1. Admins may do this in the server console, or by deploying this tool.")
		end
	end
end

-- Disable nav_edit on holster, only if it is already enabled and no other players hold an editing tool
function TOOL:Holster()
	if SERVER and GetConVar("nav_edit"):GetBool() then
		for k,v in pairs(player.GetAll()) do
			if v ~= self:GetOwner() and v:Alive() and nzu.IsAdmin(v) then
				local tool = v:GetTool()
				if tool and tool.nzu_NavEdit then return true end
			end
		end
		RunConsoleCommand("nav_edit", "0")
	end
	return true
end

function TOOL:LeftClick(trace)
	if SERVER then

	end
	return false
end

function TOOL:RightClick(trace)
	if SERVER then

	end
	return false
end

function TOOL:Reload(trace)
	if SERVER then
		local rooms, outmaps = analyze()
		for k,v in pairs(rooms) do
			local area = navmesh.GetNavAreaByID(k)
			if type(v) == "table" then
				local i = 0
				local str = "Connected to: "
				for k2,v2 in pairs(v) do
					debugoverlay.Box(area:GetCorner(0) + Vector(0,0,i), Vector(area:GetSizeX(), area:GetSizeY(), 0), Vector(0,0,0), 10, ColorAlpha(HSLToColor(k2 * 64, 1, 0.5), 100))
					i = i + 10
					str = str .. k2 .. ", "
				end
				debugoverlay.Text(area:GetCenter() + Vector(0,0,i), str, 10)
			else
				debugoverlay.Text(area:GetCenter(), v, 10)
				debugoverlay.Box(area:GetCorner(0), Vector(area:GetSizeX(), area:GetSizeY(), 0), Vector(0,0,0), 10, HSLToColor(v * 64, 1, 0.5))
			end
		end

		for k,v in pairs(outmaps) do
			local area = navmesh.GetNavAreaByID(k)
			if type(v) == "table" then
				local i = 0
				local str = ""
				for k2,v2 in pairs(v) do
					debugoverlay.Box(area:GetCorner(0) + Vector(0,0,i), Vector(area:GetSizeX(), area:GetSizeY(), 0), Vector(0,0,0), 10, Color(255,0,0)) --ColorAlpha(HSLToColor(k2 * 64, 1, 0.5), 10))
					i = i + 10
					str = str .. k2 .. ", "
				end
				debugoverlay.Text(area:GetCenter() + Vector(0,0,i), str, 10)
			else
				debugoverlay.Text(area:GetCenter(), "Reaching: "..v, 10)
				debugoverlay.Box(area:GetCorner(0), Vector(area:GetSizeX(), area:GetSizeY(), 0), Vector(0,0,0), 10, ColorAlpha(HSLToColor(v * 64, 1, 0.5), 10))
			end
		end
	end
	return true
end

if CLIENT then
	TOOL.Information = {
		--{name = "left", stage = 0},
		--{name = "right", stage = 0},
		{name = "reload", stage = 0},

		--{name = "left_markdoor", stage = 1},
		--{name = "right_marknav", stage = 1},
		--{name = "left_done", stage = 1, icon2 = "gui/e.png"},
		--{name = "reload_cancel", stage = 1},
	}

	language.Add("tool.nzu_tool_navrooms.name", "Nav Rooms Editor")
	language.Add("tool.nzu_tool_navrooms.desc", "Associate Navmeshes to Room names. Any entities inside these navmeshes belong to this room.")

	language.Add("tool.nzu_tool_navrooms.left", "Mark Door")
	language.Add("tool.nzu_tool_navrooms.right", "Toggle Permanent Lock")
	language.Add("tool.nzu_tool_navrooms.reload", "Preview Room (Requires 'developer 1' in console)")

	language.Add("tool.nzu_tool_navrooms.left_markdoor", "Toggle whether Navmesh is a Border")
	language.Add("tool.nzu_tool_navrooms.right_marknav", "Generate Room inside Borders")
	language.Add("tool.nzu_tool_navrooms.left_done", "Save")
	language.Add("tool.nzu_tool_navrooms.reload_cancel", "Cancel")

	--[[function TOOL.BuildCPanel(panel)
		
	end]]
end

nzu.RegisterTool("navrooms", TOOL)