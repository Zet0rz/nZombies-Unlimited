local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"

-- Also allow spawnmenu spawning
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Invisible Wall"
ENT.Author = "Zet0r"
ENT.Spawnable = true

local defaultmodel = "models/hunter/plates/plate5x5.mdl"
local col = Color(255,150,0,100)
local mat = "models/wireframe"

function ENT:Initialize()
	if SERVER then
		self:SetNoDraw(NZU_NZOMBIES)
		self:UpdateModel(defaultmodel)
	end

	if NZU_NZOMBIES then
		self:EnableCustomCollisions(true)
	end

	self:DrawShadow(false)
	self:SetColor(col)
	self:SetMaterial(mat)
end

function ENT:UpdateModel(mdl)
	self:SetModel(mdl)
	self:PhysicsInit(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetContents(CONTENTS_PLAYERCLIP)
		phys:EnableMotion(false)
	end
end

function ENT:TestCollision() end -- Return nothing = trace ignores, bullets and all entities go through (except players! :D)
if CLIENT then function ENT:Draw() self:DrawModel() end end

scripted_ents.Register(ENT, "nzu_prop_playerclip")

if not NZU_SANDBOX then return end
--[[-------------------------------------------------------------------------
Tool for spawning wall buys, browses weapon classes through filters
---------------------------------------------------------------------------]]
local TOOL = {}
TOOL.Category = "Mapping"
TOOL.Name = "#tool.nzu_tool_invisibleprop.name"

TOOL.ClientConVar = {
	["model"] = defaultmodel,
}

function TOOL:LeftClick(trace)
	if SERVER then
		local ply = self:GetOwner()

		local e = ents.Create("nzu_prop_playerclip")
		e:SetPos(trace.HitPos)
		e:SetAngles(trace.HitNormal:Angle() + Angle(90,0,0))
		e:Spawn()
		e:UpdateModel(self:GetClientInfo("model"))
		
		if IsValid(ply) then
			undo.Create("Invisible Prop")
				undo.SetPlayer(ply)
				undo.AddEntity(e)
			undo.Finish()
		end
	end
	return true
end

function TOOL:RightClick(trace)
	if self:GetStage() == 0 then
		local trace = trace
		if not IsValid(trace.Entity) or trace.Entity:GetClass() ~= "nzu_prop_playerclip" then
			trace = util.TraceLine({
				start = trace.HitPos,
				endpos = trace.HitPos - trace.Normal * 1,
				ignoreworld = true,
				filter = trace.Entity,
			})
		end

		if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_prop_playerclip" then
			if SERVER then
				self.TargetedEntity = trace.Entity
				self.LocalAng = trace.HitNormal:Angle()
				self.LocalPos = trace.Entity:WorldToLocal(trace.HitPos)
				self:SetStage(1)
			end
			return true
		end
	else
		if SERVER then
			if IsValid(self.TargetedEntity) then
				local trace = trace
				if trace.Entity == self.TargetedEntity then
					trace = util.TraceLine({
						start = trace.HitPos,
						endpos = trace.HitPos + trace.Normal * 4096 * 8,
						filter = self.TargetedEntity
					})
				end

				if trace.Hit then
					self.TargetedEntity:SetAngles(trace.HitNormal:Angle() - self.LocalAng + self.TargetedEntity:GetAngles())
					self.TargetedEntity:SetPos(self.TargetedEntity:LocalToWorld(self.TargetedEntity:WorldToLocal(trace.HitPos) - self.LocalPos))
					--self:GetOwner():SetPos(self.TargetedEntity:GetPos())
				end
			end

			self:SetStage(0)
			self.TargetedEntity = nil
			self.LocalPos = nil
			self.LocalAng = nil
		end
		return true
	end
	
end

function TOOL:Reload(trace)
	if self:GetStage() ~= 0 then self:SetStage(0) return true end
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_prop_playerclip" then
		if SERVER then trace.Entity:SetMaterial(trace.Entity:GetMaterial() == "" and mat or "") end
		return true
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left", stage = 0},
		{name = "right", stage = 0},
		{name = "reload", stage = 0},

		{name = "right_finish", stage = 1},
		{name = "reload_cancel", stage = 1}
	}

	language.Add("tool.nzu_tool_invisibleprop.name", "Invisible Wall")
	language.Add("tool.nzu_tool_invisibleprop.desc", "Creates a prop that will be invisible in-game and only collide with Players.")

	language.Add("tool.nzu_tool_invisibleprop.left", "Create Invisible Plate")
	language.Add("tool.nzu_tool_invisibleprop.right", "Target Plate to Align to Wall")
	language.Add("tool.nzu_tool_invisibleprop.reload", "Toggle Wireframe Material")

	language.Add("tool.nzu_tool_invisibleprop.right_finish", "Align targeted Plate to Surface")
	language.Add("tool.nzu_tool_invisibleprop.reload_cancel", "Cancel Align")

	function TOOL.BuildCPanel(panel)
		panel:Help("Spawn a prop that collides only with players, and cannot be seen in nZombies Unlimited.")

		panel:TextEntry("Model", "nzu_tool_invisibleprop_model")

		panel:Help("Tip: You can right-click any model in the Spawn Menu and 'Copy to clipboard', then paste in the text box above for that model.")

		local f = file.Read("settings/spawnlist_default/008-plastic.txt", "GAME")
		print(f)
		if f then
			local tbl = util.KeyValuesToTable(f)
			if tbl then
				local scroll = vgui.Create("DScrollPanel", panel)
				local p = vgui.Create("DIconLayout", scroll)
				p:Dock(FILL)
				--p:SetSpaceX(5)
				--p:SetSpaceY(5)

				for k,v in pairs(tbl.contents) do
					if v.type == "model" and string.find(v.model, "plate") then
						local icon = p:Add("SpawnIcon")
						icon:SetModel(v.model)
						icon.DoClick = function()
							RunConsoleCommand("nzu_tool_invisibleprop_model", v.model)
						end
					end
				end

				scroll:SetTall(600)
				panel:AddItem(scroll)
			end
		end
	end
end

nzu.RegisterTool("invisibleprop", TOOL)