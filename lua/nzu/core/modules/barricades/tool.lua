local TOOL = {}
TOOL.Category = "Mapping"
TOOL.Name = "#tool.nzu_tool_barricade.name"

TOOL.ClientConVar = {
	["vaults"] = "1",
	["planks"] = "1",
}

function TOOL:LeftClick(trace)
	if SERVER then
		local ply = self:GetOwner()

		local e = ents.Create("nzu_barricade")
		e:SetPos(trace.HitPos)
		e:SetAngles(Angle(0,(ply:GetPos() - trace.HitPos):Angle()[2] + 180,0))
		e:SetTriggerVault(self:GetClientNumber("vaults") ~= 0)
		if self:GetClientNumber("planks") == 0 then e:SetMaxPlanks(0) end
		e:Spawn()
		
		if IsValid(ply) then
			undo.Create("Barricade")
				undo.SetPlayer(ply)
				undo.AddEntity(e)
			undo.Finish()
		end
	end
	return true
end

function TOOL:RightClick(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_barricade" then
		if SERVER then
			local tr = util.TraceLine({
				start = trace.Entity:GetPos(),
				endpos = trace.Entity:GetPos() - Vector(0,0,128),
				filter = trace.Entity
			})
			if tr.Hit then
				trace.Entity:SetPos(tr.HitPos)
				local ang = trace.Entity:GetAngles()
				ang.p = 0
				ang.r = 0
				trace.Entity:SetAngles(ang)
			end
		end
		return true
	end
end

function TOOL:Reload(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_barricade" then
		if SERVER then trace.Entity:Remove() end
		return true
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left"},
		{name = "right"},
		{name = "reload"},
	}

	language.Add("tool.nzu_tool_barricade.name", "Barricade Creator")
	language.Add("tool.nzu_tool_barricade.desc", "Creates a Barricade that zombies has to break through to pass.")

	language.Add("tool.nzu_tool_barricade.left", "Create Barricade")
	language.Add("tool.nzu_tool_barricade.reload", "Remove Barricade")
	language.Add("tool.nzu_tool_barricade.right", "Align with Floor")

	function TOOL.BuildCPanel(panel)
		panel:Help("Spawn a Barricade at the target location. Zombies have to break its planks before they can pass it. Players can never pass them, even without planks.")

		panel:CheckBox("Has Planks", "nzu_tool_barricade_planks")
		panel:CheckBox("Triggers Vaults", "nzu_tool_barricade_vaults")
		panel:Help("Barricades with no planks that trigger Vaults can be used to make vaultable props that players can't pass.")
		panel:Help("When a Zombie is vaulting, it is no-collided to any and all props and entities.")
	end
end

nzu.RegisterTool("barricade", TOOL)