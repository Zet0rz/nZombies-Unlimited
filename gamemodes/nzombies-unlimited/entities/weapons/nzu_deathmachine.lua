

SWEP.ViewModel = "models/weapons/c_zombies_deathmachine.mdl" -- Change these later
SWEP.WorldModel = "models/weapons/w_zombies_deathmachine.mdl"
SWEP.UseHands = true
SWEP.HoldType = "shotgun"

if SERVER then
	SWEP.AutoSwitchTo = true
	SWEP.AutoSwitchFrom = false

	SWEP.nzu_PreventBox = true
	SWEP.nzu_DefaultWeaponSlot = "Powerup"
else
	SWEP.PrintName = "Death Machine"
	SWEP.DrawAmmo = false
end

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= true
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW)
end

local shootsound = Sound("nz/deathmachine/loop_l_.wav") -- Change this later
local function calculatedamage(wep, tr, dmg)
	local zomb = tr.Entity
	if IsValid(zomb) and zomb:IsZombie() then
		dmg:SetDamage(zomb:GetMaxHealth()*0.25)
	end
end

function SWEP:PrimaryAttack()
	local shootpos = self.Owner:GetShootPos()
	local shootang = self.Owner:GetAimVector()
	
	local bullet = {}
	bullet.Damage = 100
	bullet.Force = 10
	bullet.Tracer = 1
	bullet.TracerName = "AirboatGunHeavyTracer"
	bullet.Src = shootpos
	bullet.Dir = shootang + Vector(0,0,0)
	bullet.Spread = Vector(0.02, 0.02, 0)
	if SERVER then bullet.Callback = calculatedamage end

	self.Owner:MuzzleFlash()
	self.Owner:FireBullets(bullet)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self.Owner:SetAnimation(PLAYER_ATTACK1)
	self.Owner:ViewPunch(Angle(math.Rand(-0.5,-0.3), math.Rand(-0.3,0.3), 0 ))

	self:SetNextPrimaryFire(CurTime() + 0.05)
	self:EmitSound(shootsound)
end

-- Internals. You shouldn't overwrite this logic unless you know what you're doing, or you want the weapon to not interact with powerups this way
-- On holster: If the weapon was given through a powerup, remove the powerup.
function SWEP:Holster(wep)
	if SERVER and self.nzu_Powerup then
		self:GetOwner():TerminatePowerup(self.nzu_Powerup)
	end
	return true
end

-- On removal: Same as holster, remove the powerup
function SWEP:OnRemove()
	if SERVER and self.nzu_Powerup then
		self:GetOwner():TerminatePowerup(self.nzu_Powerup)
	end
end