
SWEP.PrintName = "MK3A2 Grenade"
SWEP.ViewModel = "models/weapons/c_grenade.mdl"
SWEP.WorldModel = "models/weapons/w_grenade.mdl"

if CLIENT then
	SWEP.Author = "Zet0r"
	SWEP.Purpose = "Grenade for nZombies Unlimited"
	SWEP.Instructions = "Deploy the weapon to throw a grenade"

	SWEP.DrawAmmo = false
	--SWEP.DrawCrosshair = false
	SWEP.UseHands = true
else
	SWEP.AutoSwitchTo = false
	SWEP.AutoSwitchFrom = false
end

SWEP.HoldType = "grenade"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

-- Grenade-specific values
SWEP.DeployDelay = 0.2
SWEP.HolsterDelay = 0.2
SWEP.ThrowForce = 1000

SWEP.GrenadeCanCook = true
SWEP.GrenadeTime = 3
SWEP.GrenadeDamage = 150
SWEP.GrenadeDamageRadius = 250

--[[-------------------------------------------------------------------------
Force the weapon to always be loaded into the Grenade slot (unless otherwise specified)
---------------------------------------------------------------------------]]
SWEP.nzu_DefaultWeaponSlot = "Grenade"

-- We do our own logic for special deploying this weapon if it is in the knife slot
-- This function replaces SWEP:Deploy() on creation when given into a Knife slot
-- SWEP:Deploy() is then moved to SWEP:OldDeploy() (which can be called if wanted)
function SWEP:SpecialDeployGrenade()
	self.Owner:SetWeaponLocked(true)
	self:PrimaryAttack()
end

function SWEP:PrimaryAttack()
	self.IsThrowing = true

	self:DeployAnimation()
	self.ThrowTime = CurTime() + self.DeployDelay
end

function SWEP:DeployAnimation()
	self:SendWeaponAnim(ACT_VM_DRAW)
	timer.Simple(self.DeployDelay, function() if IsValid(self) then self:SendWeaponAnim(ACT_VM_PULLBACK_HIGH) end end)
end

function SWEP:ThrowAnimation()
	self:SendWeaponAnim(ACT_VM_THROW)
	self.Owner:SetAnimation(PLAYER_ATTACK1)
end

if SERVER then
	function SWEP:ThrowGrenade()
		local aim = self.Owner:GetAimVector()
		local throwpos = self.Owner:GetShootPos()

		local nade = ents.Create("npc_grenade_frag")
		nade:SetPos(throwpos + aim*10)
		nade:SetOwner(self.Owner)
		nade:Spawn()
		nade:GetPhysicsObject():ApplyForceCenter(aim*self.ThrowForce)

		timer.Simple(self.GrenadeTime - (CurTime() - self.ThrowTime), function()
			if IsValid(nade) then
				local e = EffectData()
				e:SetOrigin(nade:GetPos())
				util.Effect("Explosion", e, false, true)

				nade:Remove()
				util.BlastDamage(nade, self.Owner, nade:GetPos(), self.GrenadeDamageRadius, 1)
			end
		end)
	end
end

function SWEP:OnThrowFinished()
	self.Owner:SetWeaponLocked(false)
	self.Owner:SelectPreviousWeapon()
end

function SWEP:Overcook()
	if SERVER then
		local e = EffectData()
		e:SetOrigin(self.Owner:GetPos())
		util.Effect("Explosion", e, false, true)

		self:Finish() -- Finish before downing so that weapons are unlocked before the downed logic tries to switch to pistol
		self.Owner:DownPlayer()
	end
end

function SWEP:Finish()
	self.ThrowTime = nil
	self.HolsterTime = nil
	self.IsThrowing = nil
	self:OnThrowFinished()
end

function SWEP:Think()
	if self.IsThrowing and CurTime() >= self.ThrowTime then
		if not self.HolsterTime then

			if self.GrenadeCanCook and self:IsSpecialSlotKeyStillDown() then -- Don't throw yet if we're cooking!
				if CurTime() >= self.ThrowTime + self.GrenadeTime then
					self:Overcook()
				end
			return end

			self:ThrowAnimation()
			if SERVER then self:ThrowGrenade() end
			self.HolsterTime = CurTime() + self.HolsterDelay
		elseif CurTime() >= self.HolsterTime then
			self:Finish()
		end
	end
end

function SWEP:Holster(wep)
	return not self.IsThrowing
end