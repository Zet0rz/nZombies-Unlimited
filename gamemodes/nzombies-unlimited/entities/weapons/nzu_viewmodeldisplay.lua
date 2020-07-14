
-- Viewmodel Animation Weapon
-- This weapon can be given to players to execute any model and animation on their viewmodel
-- It is flexible with conditions when to finish the animation, and locks the player from switching away from the weapon until it is done
-- See functions in nzombies-unlimited/gamemode/viewmodeldisplay.lua

-- This class can also be used as the base for a new weapon if you want more hard-coded logic
-- Do so by implementing the base as "nzu_viewmodeldisplay" and implement the following:

-- 		-> Call self:Finish() shared when the animation is done

--[[-------------------------------------------------------------------------
Manipulate the viewmodel
---------------------------------------------------------------------------]]

-- SWEP:SetViewmodel(string)
-- Sets the viewmodel displayed with this weapon
function SWEP:SetViewModel(model)
	self.ViewModel = model
	if self.Owner:GetActiveWeapon() == self then
		self.Owner:GetViewModel():SetWeaponModel(model, self)
	end
end

-- SWEP:SetViewSequence(string)
-- Sets the animation played on the viewmodel by Sequence name
function SWEP:SetViewSequence(seq)
	self.Sequence = seq
	self.IsAct = false
	if self.Owner:GetActiveWeapon() == self then
		local vm = self.Owner:GetViewModel()
		vm:SendViewModelMatchingSequence(vm:LookupSequence(seq))
	end
end

-- SWEP:SetViewAct(ACT_ enum)
-- Sets the animation played on the viewmodel by ACT
function SWEP:SetViewAct(act)
	self.Sequence = act
	self.IsAct = true

	if self.Owner:GetActiveWeapon() == self then
		local vm = self.Owner:GetViewModel()
		vm:SendViewModelMatchingSequence(vm:SelectWeightedSequence(act))
	end
end

-- SWEP:SetDisplayName(string)
-- Sets the name on the HUD of the viewmodel

--[[-------------------------------------------------------------------------
Control conditional ending
---------------------------------------------------------------------------]]

-- SWEP:RemoveOnCondition(function(self, vm))
-- Sets a function that runs on Think. When this returns true, the viewmodel animation is over
-- The function receives self (the weapon) and vm (the viewmodel entity) as arguments
function SWEP:RemoveOnCondition(f)
	self.RemoveCondition = f
end

-- SWEP:RemoveOnAnimationEnd()
-- Sets the weapon to be removed when the viewmodel cycle hits >=1
-- Thus, this only works on animations that do not loop (as loops often revert to 0 at around 0.99)
-- Use time if used with looping animations
function SWEP:RemoveOnAnimationEnd()
	self.RemoveCondition = self._RemoveOnAnimationEnd
end

-- SWEP:RemoveAtTime(number)
-- Sets the weapon to be removed at the specified timestamp (CurTime-relative)
function SWEP:RemoveAtTime(t)
	self.RemoveAfter = t
	self.RemoveCondition = self._RemoveAtTime
end

-- SWEP:RemoveAfterTime(number)
-- Shortcut for RemoveAtTime to specify a delay instead of a CurTime-relative timestamp
function SWEP:RemoveAfterTime(t)
	self:RemoveAtTime(CurTime() + t)
end

-- SWEP:NoRemove()
-- Clears the remove conditions back to never being removed
function SWEP:NoRemove()
	self.RemoveCondition = nil
end

-- Internals used in the above conditions
function SWEP:_RemoveOnAnimationEnd(vm)
	return vm:GetCycle() >= 1
end
function SWEP:_RemoveAtTime()
	return CurTime() >= self.RemoveAfter
end

--[[-------------------------------------------------------------------------
Internals
---------------------------------------------------------------------------]]
function SWEP:SetupDataTables()
	self:NetworkVar("String", 0, "DisplayName")
	self:NetworkVar("Bool", 0, "ToRemove")

	if CLIENT then
		self:NetworkVarNotify("DisplayName", self.ChangeName)
		self:NetworkVarNotify("ToRemove", self.OnToRemove)
	end
end

if CLIENT then
	function SWEP:ChangeName(key, old, new)
		self.PrintName = new
	end

	function SWEP:OnToRemove(key, old, new)
		if new and not old then
			self.RemoveCondition = nil
			self.Owner:SelectPreviousWeapon() -- Also do it on client
		end
	end
end

-- Think: Where logic is done to holster the weapon
-- This sets the network var ToRemove to true when the removal condition is met
-- On server, the NetworkVarNotify causes the client to holster it with a slight networking delay
-- If the condition is shared, both client and server will set it, making the client do it in prediction (Prefer this!)
function SWEP:Think()
	if self.RemoveCondition then
		if self:RemoveCondition(self.nzu_VM) then
			self.RemoveCondition = nil
			self:Finish()
		end
	end
end

function SWEP:Finish()
	self:SetToRemove(true)
	self.Owner:SelectPreviousWeapon() -- Trigger a desire to switch to the previous weapon
end

function SWEP:Deploy()
	local vm = self.Owner:GetViewModel()
	if self.ViewModel then vm:SetWeaponModel(self.ViewModel, self) end
	if self.Sequence then vm:SendViewModelMatchingSequence(self.IsAct and vm:SelectWeightedSequence(self.Sequence) or vm:LookupSequence(self.Sequence)) end
	self.nzu_Owner = self.Owner
	self.nzu_VM = vm
end

function SWEP:Holster()
	if self:GetToRemove() then -- We may only holster while we are done
		if SERVER then self:Remove() end
		return true
	end
end

weapons.Register({Base = "nzu_viewmodeldisplay", UseHands = true}, "nzu_viewmodeldisplay_c")