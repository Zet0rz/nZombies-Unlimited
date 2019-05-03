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

-- TODO: Ray traces are taken care of, but find a way to make Hull traces ignore the entity unless PLAYERCLIP mask? :(

function ENT:Initialize()
	if SERVER then
		self:SetNoDraw(NZU_NZOMBIES)
		self:UpdateModel(self:GetModel() ~= "models/error.mdl" and self:GetModel() or defaultmodel)
	end

	if NZU_NZOMBIES then
		self:SetSolidFlags(FSOLID_CUSTOMRAYTEST) -- Runs TestCollision but ONLY for ray traces! (i.e. bullets and view traces)
	end

	self:DrawShadow(false)
	self:SetColor(col)
	self:SetMaterial(mat)
end

function ENT:UpdateModel(mdl)
	self:SetModel(mdl)
	self:PhysicsInit(SOLID_VPHYSICS)
	--self:SetSolid(SOLID_CUSTOM)
	--self:SetCollisionBounds(Vector(0,0,0), Vector(0,0,0))

	--self:SetPos(Vector(0,0,0))
	--local a,b = self:GetModelBounds()
	--[[local a,b = Vector(-20,-20,-20), Vector(20,20,200)
	self:PhysicsInitConvex({
		a,
		Vector(a.x,a.y,b.z),
		Vector(a.x,b.y,a.z),
		Vector(b.x,a.y,a.z),
		Vector(a.x,b.y,b.z),
		Vector(b.x,a.y,b.z),
		Vector(b.x,b.y,a.z),
		b
	})
	print(a,b)
	self:EnableCustomCollisions(true)]]

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetContents(CONTENTS_PLAYERCLIP) -- This only allows props to pass through, it does nothing for traces D:
		phys:SetMaterial("default_silent")
		phys:EnableMotion(false)
		phys:Sleep()
	end
end

function ENT:TestCollision(start, delta, box, extents, mask)
	-- Nothing! This runs when the entity is shot through - we return nothing to let the trace pass right through!
end
if CLIENT then function ENT:Draw() self:DrawModel() end end

-- Support Door Tool, but have our own door handling logic
ENT.nzu_CanDoor = true -- This entity can be given a Door Lock
ENT.nzu_DoorHooked = true -- When given a door lock, this is instead a non-networked Group hook

-- nzu_DoorHooked means this can be given door data, but it won't get a DoorData function - it'll just get hooked into that group and OpenDoor'd when that is opened
if SERVER then	
	function ENT:OpenDoor()
		self:Remove() -- No fancy effects, just remove
	end
end

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
	language.Add("tool.nzu_tool_invisibleprop.desc", "Creates a prop that will be invisible in-game and only collide with Players and Zombies.")

	language.Add("tool.nzu_tool_invisibleprop.left", "Create Invisible Plate")
	language.Add("tool.nzu_tool_invisibleprop.right", "Target Plate to Align to Wall")
	language.Add("tool.nzu_tool_invisibleprop.reload", "Toggle Wireframe Material")

	language.Add("tool.nzu_tool_invisibleprop.right_finish", "Align targeted Plate to Surface")
	language.Add("tool.nzu_tool_invisibleprop.reload_cancel", "Cancel Align")

	function TOOL.BuildCPanel(panel)
		panel:Help("Spawn a prop that collides only with players and NPCs, which cannot be seen in nZombies Unlimited.")

		panel:TextEntry("Model", "nzu_tool_invisibleprop_model")

		panel:Help("Tip: You can right-click any model in the Spawn Menu and 'Copy to clipboard', then paste in the text box above for that model.")

		local f = file.Read("settings/spawnlist_default/008-plastic.txt", "GAME")
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