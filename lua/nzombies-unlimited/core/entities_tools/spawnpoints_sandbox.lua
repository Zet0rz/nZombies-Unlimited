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
	self:EnableMapFlags("Spawnpoints")
end

if CLIENT then
	function SPAWNPOINT_ZOMBIE:Draw()
		self:DrawModel()
	end
end
scripted_ents.Register(SPAWNPOINT_ZOMBIE, "nzu_spawnpoint")

local spawnpointtypes = {
	["zombie"] = {"Zombie Spawnpoint", Color(0,255,0)},
	["special"] = {"Special Spawnpoint", Color(255,0,0)},
	["player"] = {"Player Spawnpoint", Color(0,0,255)}
}

local TOOL = {}
TOOL.Category = "Basic"
TOOL.Name = "#tool.nzu_tool_spawnpoint.name"

TOOL.ClientConVar = {
	["type"] = "zombie",
	["flags"] = "",
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
			e:SetColor(spawnpointtypes[spawntype][2])
			e.SpawnpointType = spawntype
			e:Spawn()

			local flags = self:GetClientInfo("flags")
			local tbl = flags == "" and {} or string.Explode(" ", flags)
			e:SetMapFlags(tbl)

			if IsValid(ply) then
				undo.Create(spawnpointtypes[spawntype][1])
					undo.SetPlayer(ply)
					undo.AddEntity(e)
				undo.Finish()
			end

			return true
		end
	end
end

function TOOL:RightClick(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_spawnpoint" then
		if self:GetClientNumber("filter") ~= 0 then
			if trace.Entity.SpawnpointType ~= self:GetClientInfo("type") then return end
		end

		trace.Entity:Remove()
		return true
	end
end

function TOOL:Reload(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_spawnpoint" then
		if self:GetClientNumber("filter") ~= 0 then
			if trace.Entity.SpawnpointType ~= self:GetClientInfo("type") then return end
		end

		local flags = self:GetClientInfo("flags")
		local tbl = flags == "" and {} or string.Explode(" ", flags)
		trace.Entity:SetMapFlags(tbl)
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
	language.Add("tool.nzu_tool_spawnpoint.reload", "Reapply selected Map Flags")

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

		panel:Help("Spawnpoints only activate when the doors belonging to at least one of the selected flags are opened. If none are selected, the Spawnpoint is always activated.")

		local listbox = vgui.Create("nzu_MapFlagsPanel", panel)
		--[[listbox:SetSelectedFlags(string.Explode(" ", GetConVar("nzu_tool_spawnpoint_flags"):GetString()))
		listbox.OnSelectedFlagsChanged = function()
			local flags = listbox:GetSelectedFlags()
			GetConVar("nzu_tool_spawnpoint_flags"):SetString(table.concat(flags, " "))
		end]]
		listbox:SetConVar("nzu_tool_spawnpoint_flags")
		panel:AddItem(listbox)
		listbox:RefreshFlags()

		panel:Help("Flags cannot contain spaces.")
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
				table.insert(tbl, {Pos = v:GetPos(), Ang = v:GetAngles(), Type = v.SpawnpointType, MapFlags = v:GetMapFlags()})
			end

			return tbl
		end,
		Save = function()
			-- We do our work in PreSave just cause we already loop there anyway
		end,
		Load = function() end,
		PreLoad = function(tbl)
			for k,v in pairs(tbl) do
				if spawnpointtypes[v.Type] then
					local e = ents.Create("nzu_spawnpoint")
					e:SetColor(spawnpointtypes[v.Type][2])
					e:SetPos(v.Pos)
					e:SetAngles(v.Ang)
					e.SpawnpointType = v.Type
					e:Spawn()
					e:SetMapFlags(v.MapFlags)
				end
			end
		end
	})
end