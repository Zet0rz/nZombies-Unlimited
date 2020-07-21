--------------------------------- VERSION: Give Player temporary Viewmodel Anim weapon


--[[local PLAYER = FindMetaTable("Player")

function PLAYER:SendViewModelAnimation(model, seq, name, c_hands)
	local w = self:GiveWeaponInSlot(c_hands and "nzu_viewmodeldisplay_c" or "nzu_viewmodeldisplay", "Display")
	w:SetViewModel(model)
	if type(seq) == "number" then
		w:SetViewAct(seq)
	else
		w:SetViewSequence(seq)
	end
	w:SetDisplayName(name)

	return w
end

if CLIENT then
	-- Weapons in "Display" are instantly deployed upon receiving
	-- Done clientside to preserve prediction (in case some weapons/anims need that)
	nzu.SpecialWeaponSlot("Display", function(wep)
		input.SelectWeapon(wep)
	end)
end

function PLAYER:TVM()
	self:Spawn()
	self:Give("weapon_ar2")
	self:Give("weapon_pistol")
end

function PLAYER:TVM2()
	self:SendViewModelAnimation("models/weapons/c_revive_morphine.mdl", ACT_VM_DRAW, "Morphine Syringe", true)
end]]







--------------------------------- VERSION: Let already-existing weapons activate Animations by switching to themselves and playing the animation

local PLAYER = FindMetaTable("Player")
local WEAPON = FindMetaTable("Weapon")

--[[-------------------------------------------------------------------------
These functions should be used SHARED! Use Network functions below if you wish to use these Server-side only!
---------------------------------------------------------------------------]]
local function performviewmodelanim(self, seq, noautoend)
	local viewmodel = self:GetOwner():GetViewModel()
	local seqid, seqdur
	if type(seq) == "number" then
		seqid = viewmodel:SelectWeightedSequence(seq)
		if not noautoend then seqdur = viewmodel:SequenceDuration(seqid) end
	else
		seqid, seqdur = viewmodel:LookupSequence(seq)
	end
	viewmodel:SendViewModelMatchingSequence(seqid)
end

function WEAPON:DoViewModelAnimation(seq, noautoend)
	self:GetOwner():SetWeaponLocked(self)

	-- If the weapon isn't deployed, we must change to it and set the animation to start once it's deployed
	if self:GetOwner():GetActiveWeapon() ~= self then

		-- Overwrite the Deploy function to play the animation
		local olddeploy = self.Deploy
		self.Deploy = function(self)
			olddeploy(self)
			performviewmodelanim(self, seq, noautoend)
			self.Deploy = olddeploy
		end

		-- Then make the change! If this is called shared, it will be predicted
		if SERVER then
			self:GetOwner():SelectWeapon(self:GetClass())
		else
			input.SelectWeapon(self)
		end
	else
		-- If it is already deployed, we can just play the animation/sequence instantly
		performviewmodelanim(self, seq, noautoend)
	end


	-- Prevent holstering until it is done! This is done by overwriting the weapon's Holster function
	-- 4) Auto-holster when it is done

	-- Needs a functionality to make it not "end" until WEAPON:EndViewModelAnimation()
end

function WEAPON:EndViewModelAnimation()

end







--------------------------------- VERSION: Don't switch weapons, instead make current weapon invisible and play animation on second viewmodel
--[[local PLAYER = FindMetaTable("Player")
local WEAPON = FindMetaTable("Weapon")

function PLAYER:ViewModelAnimation(model, seq, noautoend)
	self:DrawViewModel(false)
	self:DrawViewModel(true, 2)

	local vm = self:GetViewModel(2)
	vm:SetWeaponModel(model, self:GetActiveWeapon())
end]]