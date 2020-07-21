-- This weapon base provides basic functionality for a weapon that deploys itself immediately after being given
-- Upon doing so, it will play the animation specified in SWEP.Animation. Alternatively, you can overwrite SWEP:Deploy to do your own thing
-- The weapon is automatically removed upon holstering (i.e. when the animation is done)
-- You can override SWEP:Think to add your own removal logic (call self:Finish())
-- Otherwise, it is by default removed when the animation is done
-- The weapon cannot be holstered until this condition is met

-- Functions and fields for you to use
--[[ Copy/Paste from this block comment

SWEP.UseHands = true/false
SWEP.ViewModel = ""
SWEP.WorldModel = ""
SWEP.HoldType = ""

if CLIENT then
	SWEP.PrintName = ""
end

SWEP.Animation = "" -- ACT_VM_ enum or sequence string
SWEP.nzu_InstantDeploy = true/false -- Whether to instantly deploy this animation, or wait for the prior weapon to holster first
SWEP.PlayerCarried = true -- !-> Setting this makes the weapon to be carried by the player rather than temporarily held. You have to run weapon:DeployAnimation() to run the animation. This will make the weapon not auto-deploy on equip, and also not auto-remove on holster.
SWEP.ForceDeploy = true -- !-> Setting this makes the weapon force deployment (regardless of any hooks and predictions!) using server-side player:SetActiveWeapon()

]]

-- Functions to overwrite (Note: These only work if their respective original functions are not overwritten)
function SWEP:OnDeploy() end
function SWEP:OnFinish() end
function SWEP:OnThink() end



-- Functions to use
function SWEP:Finish() -- Marks animation as done and returns to previous weapon. Use this shared (for prediction)!
	self.IsAnimating = nil
	self:OnFinish()
	self:GetOwner():SelectPreviousWeapon()
end

-- Run this function to deploy the weapon and run its animation. Use this in prediction(!) and when SWEP.PlayerCarried is true
function SWEP:DeployAnimation()
	self:GetOwner():SelectWeaponPredicted(self)
end




-- Internals
if SERVER then
	SWEP.AutoSwitchTo = true
	SWEP.AutoSwitchFrom = false

	SWEP.nzu_PreventBox = true
	SWEP.nzu_DefaultWeaponSlot = "Animation"
else
	SWEP.DrawAmmo = false
end

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
	self.IsAnimating = true

	local vm = self:GetOwner():GetViewModel()
	if type(self.Animation) == "number" then
		self:SendWeaponAnim(self.Animation)
		self.AnimationEnd = CurTime() + vm:SequenceDuration()
	else
		-- It is a sequence string
		local seq, len = vm:LookupSequence(self.Animation)
		vm:SendViewModelMatchingSequence(seq)
		self.AnimationEnd = CurTime() + len
	end

	self:OnDeploy()
end

function SWEP:Think()
	self:OnThink()
	if self.AnimationEnd and CurTime() > self.AnimationEnd then
		self.AnimationEnd = nil
		self:Finish()
	end
end

function SWEP:Holster()
	if not self.IsAnimating then
		if SERVER and not self.PlayerCarried then self:Remove() end
		return true
	end
end

SWEP.EquipClient = true -- Run Equip clientside too (as soon as the client is aware of the weapon)
function SWEP:Equip()
	if self.ForceDeploy then
		if SERVER then self:GetOwner():SetActiveWeapon(self) end
		return
	end

	if not self.PlayerCarried then
		self:GetOwner():SelectWeaponPredicted(self)
	end
end