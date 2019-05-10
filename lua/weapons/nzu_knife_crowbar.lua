
SWEP.PrintName = "Crowbar"
SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"

if CLIENT then
	SWEP.Author = "Zet0r"
	SWEP.Purpose = "Crowbar Knife for nZombies Unlimited"
	SWEP.Instructions = "Deploy the weapon to knife"

	SWEP.DrawAmmo = false
	--SWEP.DrawCrosshair = false
	SWEP.UseHands = true
else
	SWEP.AutoSwitchTo = false
	SWEP.AutoSwitchFrom = false
end

SWEP.HoldType = "melee"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

-- Knife-specific values
SWEP.KnifeRange = 75
SWEP.KnifeDelay = 0.4
SWEP.HullAttackMins = Vector(-5,-5,-5)
SWEP.HullAttackMaxs = Vector(5,5,5)
SWEP.DamageAllNPCs = false -- Only damage 1 zombie!

-- Damage, types, and forces (for TraceHullAttack)
SWEP.Primary.Damage = 150
SWEP.Primary.DamageType = DMG_CLUB
SWEP.Primary.DamageForce = 100

if CLIENT then SWEP.HUDIcon = Material("nzombies-unlimited/hud/crowbar_icon.png", "unlitgeneric smooth") end -- CONTENT + change this to crowbar png!

--[[-------------------------------------------------------------------------
Force the weapon to always be loaded into the Knife slot (unless otherwise specified)
---------------------------------------------------------------------------]]
SWEP.nzu_DefaultWeaponSlot = "Knife"
SWEP.nzu_InstantDeploy = true -- Ignore Holster functions when deploying this weapon

-- We do our own logic for special deploying this weapon if it is in the knife slot
-- This function replaces SWEP:Deploy() on creation when given into a Knife slot
-- SWEP:Deploy() is then moved to SWEP:OldDeploy() (which can be called if wanted)
function SWEP:SpecialDeployKnife()
	self.Owner:SetWeaponLocked(true)
	self:PrimaryAttack()
end

function SWEP:SpecialSlotKnife()
	self.OldDeploy = self.Deploy
	self.Deploy = self.SpecialDeployKnife
end

function SWEP:PrimaryAttack()
	self.IsKnifing = true
	self.nzu_CanSpecialHolster = false

	self:SwingAnimation()
	if SERVER then
		self:SwingAttack()
	end

	self:SetNextPrimaryFire(CurTime() + (self.KnifeDelay or self.Primary.Delay))
end

-- Separating the functions so that sub-classes can more easily overwrite one without having to mess with another
-- This function lets you change the animation and sounds being played
local hitsound = Sound("Weapon_Crowbar.Melee_Hit")
local misssound = Sound("Weapon_Crowbar.Single")
function SWEP:SwingAnimation()
	local startpos = self.Owner:GetShootPos()
	local endpos = startpos + self.Owner:GetAimVector()*self.KnifeRange

	local tr = util.TraceLine({
		start = startpos,
		endpos = endpos,
		filter = self.Owner,
		mask = MASK_SHOT,
	})

	if tr.Hit then
		self:EmitSound(hitsound)
		self:SendWeaponAnim(ACT_VM_HITCENTER)
	else
		self:EmitSound(misssound)
		self:SendWeaponAnim(ACT_VM_MISSCENTER)
	end
	
	local ply = self.Owner
	timer.Simple(0, function() if IsValid(ply) then ply:SetAnimation(PLAYER_ATTACK1) end end)
end

-- This lets you overwrite how damage is applied
-- It is called server-side only
if SERVER then
	function SWEP:SwingAttack()
		local startpos = self.Owner:GetShootPos()
		local endpos = startpos + self.Owner:GetAimVector()*self.KnifeRange

		if self.DamageAllNPCs then
			self.Owner:TraceHullAttack(startpos, endpos, self.HullAttackMins, self.HullAttackMaxs, self.Primary.Damage, self.Primary.DamageType, self.Primary.DamageForce, self.DamageAllNPCs)
		else
			local tr = util.TraceHull({
				start = startpos,
				endpos = endpos,
				mins = self.HullAttackMins,
				maxs = self.HullAttackMaxs,
				filter = self.Owner,
			})
			if IsValid(tr.Entity) then
				local dmg = DamageInfo()
				dmg:SetDamage(self.Primary.Damage)
				dmg:SetDamageType(self.Primary.DamageType)
				dmg:SetDamageForce(self.Owner:GetAimVector()*self.Primary.DamageForce)

				dmg:SetAttacker(self.Owner)
				dmg:SetInflictor(self)

				tr.Entity:TakeDamageInfo(dmg)
			end
		end
	end
end

if CLIENT then
	function SWEP:DrawHUDIcon(x,y,h)
		surface.SetMaterial(self.HUDIcon)
		surface.SetDrawColor(255,255,255,255)
		surface.DrawTexturedRect(x-h,y,h,h)
		return h
	end
end

--[[-------------------------------------------------------------------------
Internals
---------------------------------------------------------------------------]]

function SWEP:Think()
	if self.IsKnifing and CurTime() >= self:GetNextPrimaryFire() then
		self.IsKnifing = nil
		self.nzu_CanSpecialHolster = true
		self:OnSwingFinished()
	end
end

-- This lets you change what happens when the swing is finished
-- It is predicted and shared from the Think() above
if NZU_NZOMBIES then
	function SWEP:OnSwingFinished()
		self.Owner:SetWeaponLocked(false)
		self.Owner:SelectPreviousWeapon()
	end
else
	function SWEP:OnSwingFinished()
		self.Owner:ConCommand("lastinv")
	end
end

function SWEP:Holster(wep)
	return not self.IsKnifing
end

-- Sandbox compatibility pretty much
function SWEP:Deploy()
	self:PrimaryAttack()
end