
SWEP.Base = "nzu_viewmodelanim_base" -- This base provides functionality for a viewmodel-animation based weapon

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_revive_morphine.mdl"
SWEP.WorldModel = ""
SWEP.HoldType = "slam"

if CLIENT then
	SWEP.PrintName = "Morphine Syringe"
end

SWEP.Animation = ACT_VM_DRAW -- ACT_VM_ enum or sequence string
SWEP.nzu_InstantDeploy = true -- Whether to instantly deploy this animation, or wait for the prior weapon to holster first
--SWEP.PlayerCarried = true -- Setting this makes the weapon to be carried by the player rather than temporarily held. You have to run weapon:DeployAnimation() to run the animation. This will make the weapon not auto-deploy on equip, and also not auto-remove on holster.
--SWEP.nzu_DefaultWeaponSlot = "Syringe" -- The gamemode will attempt to use this weapon slot using weapon:DeployAnimation() when reviving
--SWEP.ForceDeploy = true -- !-> Setting this makes the weapon force deployment (regardless of any hooks and predictions!) using server-side player:SetActiveWeapon()

-- We override the think function to insert our own logic for when this animation is done
function SWEP:Think()
	if not self:GetOwner().nzu_ReviveTarget then -- We only finish when we don't have a revive target
		self:Finish()
	end
end

-- Temporary! Until a new version of the model is compiled with a new origin
function SWEP:GetViewModelPosition( pos, ang )

	local newpos = LocalPlayer():EyePos()
	local newang = LocalPlayer():EyeAngles()
	local up = newang:Up()

	newpos = newpos + LocalPlayer():GetAimVector()*6 - up*63

	return newpos, newang

end