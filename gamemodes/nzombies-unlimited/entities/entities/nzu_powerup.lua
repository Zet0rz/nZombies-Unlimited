AddCSLuaFile()

--[[-------------------------------------------------------------------------
Powerup Drop Entities
---------------------------------------------------------------------------]]
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
	else
		self.ParticleEmitter = ParticleEmitter(self:GetPos())
		self.ParticleEmitter:SetNoDraw(true) -- We draw them manually
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
	AccessorFunc(ENT, "m_fPowerupDuration", "PowerupDuration")

	function ENT:SetLifetime(t)
		if t then self.Life = CurTime() + t else self.Life = nil end
	end

	function ENT:PowerupChanged(_, old, new)
		local powerup = nzu.GetPowerup(new)
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
			self:ActivatePowerup(ent)
		end
	end

	function ENT:CanBePickedUpBy(ent)
		return ent:IsPlayer() -- TODO: Negatives picked up by zombies?
	end

	-- Technically this can be overwritten, making it possible to spawn a drop from code but have it do whatever on activation
	function ENT:ActivatePowerup(ent)
		nzu.ActivatePowerup(self:GetNegative() and "-"..self:GetPowerup() or self:GetPowerup(), self:GetPos(), self:GetPersonal() and ent or nil, self:GetPowerupDuration())
		if self.GrabSound then self:EmitSound(self.GrabSound) end
		self:Remove()
	end

	function ENT:Think()
		if self.Life and CurTime() > self.Life then self:Remove() end
	end
end

if CLIENT then
	local mats = {
		"nzombies-unlimited/particle/powerup_glow_09",
		--"nzombies-unlimited/particle/powerup_wave_5",
		"nzombies-unlimited/particle/powerup_glow_09",
		--"particle/particle_glow_03"
	}

	local cols = {
		{{100,255,100},{255,255,255},{200,255,200}}, -- Global Positive: Green
		{{100,200,255},{200,255,255},{200,200,255}}, -- Personal Positive: Blue
		{{255,0,0},{200,100,100},{255,200,200}}, -- Global Negative: Red
		{{255,50,255},{255,100,255},{255,200,255}}, -- Personal Negative: Purple
	}

	local mat = Material(mats[1])
	function ENT:Draw()
		if not self.NextParticle or self.NextParticle < CurTime() then

			local col = cols[1 + (self:GetPersonal() and 1 or 0) + (self:GetNegative() and 2 or 0)]
			for k,v in pairs(mats) do
				local p = self.ParticleEmitter:Add(v, self:GetPos())
				p:SetDieTime(0.5)
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(30 - k*5)
				p:SetEndSize(40 - k*5)
				p:SetRoll(math.random()*2)
				local c = col[k]
				p:SetColor(c[1],c[2],c[3])
				p:SetLighting(false)
			end
			self.NextParticle = CurTime() + 0.2
		end

		self.ParticleEmitter:Draw()
		self:DrawModel()
	end
	ENT.DrawTranslucent = ENT.Draw

	function ENT:OnRemove()
		if IsValid(self.ParticleEmitter) then self.ParticleEmitter:Finish() end
	end

	local rotang = Angle(2,50,5)
	function ENT:Think()
		self:SetRenderAngles((self:GetRenderAngles() or self:GetAngles()) + rotang*math.sin(CurTime()/10)*FrameTime()) -- TODO: Make accurate?
	end
end