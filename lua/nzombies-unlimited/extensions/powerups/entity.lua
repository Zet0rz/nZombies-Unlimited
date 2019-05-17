local EXT = nzu.Extension()
--[[-------------------------------------------------------------------------
Powerup Drop Entities
---------------------------------------------------------------------------]]

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Power-Up"
ENT.Author = "Zet0r"

ENT.GrabSound = Sound("nzu/powerups/grab.wav")
ENT.LoopSound = Sound("nzu/powerups/loop.wav")
ENT.SpawnSound = Sound("nzu/powerups/spawn.wav")

function ENT:Initialize()
	if SERVER then
		self:PhysicsInitSphere(60, "default_silent")
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)

		self:SetTrigger(true)
		self:SetUseType(SIMPLE_USE)

		self:UseTriggerBounds(true)

		-- Move up from ground
		local tr = util.TraceLine({
			start = self:GetPos(),
			endpos = self:GetPos() - Vector(0,0,40),
			filter = self,
			mask = MASK_SOLID_BRUSHONLY,
		})
		if tr.Hit then
			self:SetPos(tr.HitPos + Vector(0,0,40))
		end
	end
	if self.SpawnSound then self:EmitSound(self.SpawnSound) end
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Powerup")
	self:NetworkVar("Bool", 0, "Personal")
	self:NetworkVar("Bool", 1, "Negative")

	if SERVER then
		self:NetworkVarNotify("Powerup", self.PowerupChanged)
	end
end

if SERVER then
	function ENT:PowerupChanged(_, old, new)
		local powerup = EXT.GetPowerup(new)
		if not powerup then
			-- Some question mark or error here?
		return end

		self:SetModel(powerup.Model)
		self:SetColor(powerup.Color)
		self:SetModelScale(powerup.Scale or 1)
		self:SetMaterial(powerup.Material or "")
	end

	function ENT:StartTouch(ent)
		if self:CanBePickedUpBy(ent) then
			
			self:ActivatePowerup()
		end
	end

	function ENT:CanBePickedUpBy(ent)
		return ent:IsPlayer() -- TODO: Negatives picked up by zombies?
	end

	-- Technically this can be overwritten, making it possible to spawn a drop from code but have it do whatever on activation
	function ENT:ActivatePowerup(ent)
		EXT.ActivatePowerup(self:GetPowerup(), self:GetPersonal() and ent or nil, nil, self:GetNegative()) -- Second nil is duration: Use default
		if self.GrabSound then self:EmitSound(self.GrabSound) end
		self:Remove()
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
	ENT.DrawTranslucent = ENT.Draw
end

scripted_ents.Register(ENT, "nzu_powerup")