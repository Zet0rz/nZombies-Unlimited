
-- Include the Entities
include("mysterybox_entities.lua")

--[[-------------------------------------------------------------------------
Mystery Box Tool
---------------------------------------------------------------------------]]
local TOOL = {}
TOOL.Category = "Weapons"
TOOL.Name = "#tool.nzu_tool_mysterybox.name"

TOOL.ClientConVar = {
	["initial"] = "0",
}

function TOOL:LeftClick(trace)
	if SERVER then
		local ply = self:GetOwner()

		local e = ents.Create("nzu_mysterybox_spawnpoint")
		e:SetPos(trace.HitPos + trace.HitNormal*0.5)
		e:SetAngles(Angle(0,(ply:GetPos() - trace.HitPos):Angle()[2],0))
		e:Spawn()
		e:SetIsPossibleSpawn(self:GetClientNumber("initial") ~= 0)
		
		if IsValid(ply) then
			undo.Create("Mystery Box Spawnpoint")
				undo.SetPlayer(ply)
				undo.AddEntity(e)
			undo.Finish()
		end
	end
	return true
end

function TOOL:Reload(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_mysterybox_spawnpoint" then
		if SERVER then trace.Entity:Remove() end
		return true
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left"},
		{name = "reload"}
	}

	language.Add("tool.nzu_tool_mysterybox.name", "Mystery Box Spawnpoint")
	language.Add("tool.nzu_tool_mysterybox.desc", "Creates a location for the Mystery Box to appear in nZombies Unlimited.")

	language.Add("tool.nzu_tool_mysterybox.left", "Create Spawnpoint")
	language.Add("tool.nzu_tool_mysterybox.reload", "Remove Spawnpoint")

	function TOOL.BuildCPanel(panel)
		panel:Help("Place locations for the Mystery Box in-game. The Box will spawn at one of these and move between them as players use it.")

		panel:CheckBox("Possible Spawn?", "nzu_tool_mysterybox_initial")
		panel:ControlHelp("If Spawnpoints with this set exists, the Box can only initially spawn at one of these.")
	end
end

nzu.RegisterTool("mysterybox", TOOL)