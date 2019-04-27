AddCSLuaFile()

local SPAWNPOINT_ZOMBIE = {}
SPAWNPOINT_ZOMBIE.Type = "anim"
SPAWNPOINT_ZOMBIE.Base = "base_entity"
SPAWNPOINT_ZOMBIE.Model = "models/player/odessa.mdl"

function SPAWNPOINT_ZOMBIE:Initialize()
	if SERVER then
		self:SetModel(self.Model)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_BBOX)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:DrawShadow(false)
	end
	self:SetRoomHandler("Spawnpoints")
end

if CLIENT then
	function SPAWNPOINT_ZOMBIE:Draw()
		self:DrawModel()
	end
end

local spawnpointtypes = {
	["zombie"] = {"Zombie Spawnpoint", Color(0,255,0)},
	["special"] = {"Special Spawnpoint", Color(255,0,0)},
	["player"] = {"Player Spawnpoint", Color(0,0,255)}
}

function SPAWNPOINT_ZOMBIE:SetSpawnpointType(spawntype)
	self.SpawnpointType = spawntype
	self:SetColor(spawnpointtypes[spawntype][2])
end

scripted_ents.Register(SPAWNPOINT_ZOMBIE, "nzu_spawnpoint")

local TOOL = {}
TOOL.Category = "Mapping"
TOOL.Name = "#tool.nzu_tool_spawnpoint.name"

TOOL.ClientConVar = {
	["type"] = "zombie",
	["rooms"] = "",
	["filter"] = "0",
}

function TOOL:LeftClick(trace)
	if SERVER then
		local spawntype = self:GetClientInfo("type")
		if spawnpointtypes[spawntype] then
			local ply = self:GetOwner()

			local e = ents.Create("nzu_spawnpoint")
			e:SetPos(trace.HitPos)
			e:SetAngles(Angle(0,(ply:GetPos() - trace.HitPos):Angle()[2],0))
			e:SetSpawnpointType(spawntype)
			e:Spawn()

			local flags = self:GetClientInfo("rooms")
			local tbl = flags == "" and {} or string.Explode(" ", flags)
			e:SetRooms(tbl)

			if IsValid(ply) then
				undo.Create(spawnpointtypes[spawntype][1])
					undo.SetPlayer(ply)
					undo.AddEntity(e)
				undo.Finish()
			end
		end
	end
	return true
end

function TOOL:RightClick(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_spawnpoint" then
		if SERVER then
			if self:GetClientNumber("filter") == 0 or trace.Entity.SpawnpointType == self:GetClientInfo("type") then
				trace.Entity:Remove()
			end
		end
		return true
	end
end

function TOOL:Reload(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_spawnpoint" then
		if SERVER then
			if self:GetClientNumber("filter") ~= 0 then
				if trace.Entity.SpawnpointType ~= self:GetClientInfo("type") then return end
			end

			local flags = self:GetClientInfo("rooms")
			local tbl = flags == "" and {} or string.Explode(" ", flags)
			trace.Entity:SetRooms(tbl)
		end
		return true
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left"},
		{name = "right"},
		{name = "reload"},
	}

	language.Add("tool.nzu_tool_spawnpoint.name", "Spawnpoint Creator")
	language.Add("tool.nzu_tool_spawnpoint.desc", "Creates spawnpoints for zombies and players.")

	language.Add("tool.nzu_tool_spawnpoint.left", "Create Spawnpoint")
	language.Add("tool.nzu_tool_spawnpoint.right", "Remove Spawnpoint")
	language.Add("tool.nzu_tool_spawnpoint.reload", "Reapply selected Rooms")

	function TOOL.BuildCPanel(panel)
		panel:Help("Spawnpoint Type")

		local selectedbutton
		local cvar = GetConVar("nzu_tool_spawnpoint_type")
		for k,v in pairs(spawnpointtypes) do
			local but = vgui.Create("DButton", panel)
			but:SetText(v[1])
			but.DoClick = function()
				if selectedbutton then
					selectedbutton:SetSelected(false)
				end

				cvar:SetString(k)
				but:SetSelected(true)
				selectedbutton = but
			end
			if cvar:GetString() == k then
				but:SetSelected(true)
				selectedbutton = but
			end

			panel:AddItem(but)
		end

		panel:CheckBox("Filter Remove and Reload to selected types only", "nzu_tool_spawnpoint_filter")

		panel:Help("Spawnpoints only activate when one of its Rooms is opened. If no Rooms are set, the Spawnpoint is always activated.")

		local listbox = vgui.Create("nzu_RoomsPanel", panel)
		listbox:SetConVar("nzu_tool_spawnpoint_rooms")
		panel:AddItem(listbox)
		listbox:RefreshRooms()

		panel:ControlHelp("Room names cannot contain spaces.")
	end

end

nzu.RegisterTool("spawnpoint", TOOL)

--[[-------------------------------------------------------------------------
Save Extension (for Server)
Sandbox variant: Save Spawnpoint data and replicate them on load
(This differs from nZombies)
---------------------------------------------------------------------------]]
if SERVER then
	nzu.AddSaveExtension("Spawnpoints", {
		PreSave = function()
			local tbl = {}

			for k,v in pairs(ents.FindByClass("nzu_spawnpoint")) do
				nzu.IgnoreSaveEntity(v) -- Don't save these entities
				table.insert(tbl, {Pos = v:GetPos(), Ang = v:GetAngles(), Type = v.SpawnpointType, Rooms = v:GetRooms()})
			end

			return tbl
		end,
		PreLoad = function(tbl)
			for k,v in pairs(tbl) do
				if spawnpointtypes[v.Type] then
					local e = ents.Create("nzu_spawnpoint")
					e:SetSpawnpointType(v.Type)
					e:SetPos(v.Pos)
					e:SetAngles(v.Ang)
					e:Spawn()
					e:SetRooms(v.Rooms)
				end
			end
		end
	})
end