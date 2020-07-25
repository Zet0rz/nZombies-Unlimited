local PLAYER = FindMetaTable("Player")
local WEAPON = FindMetaTable("Weapon")

local function doinitialize(ply)
	local primary = {Number = 1, ID = "Primary"}
	local secondary = {Number = 2, ID = "Secondary"}

	ply.nzu_WeaponSlots = {
		[1] = primary,
		[2] = secondary,
		["Primary"] = primary,
		["Secondary"] = secondary
	}
end
if SERVER then
	hook.Add("PlayerInitialSpawn", "nzu_WeaponSlotsInit", doinitialize)
else
	hook.Add("InitPostEntity", "nzu_WeaponSlotsInit", function() doinitialize(LocalPlayer()) end)

	-- Enable Clients to also have access to hook "WeaponEquip" as well as SWEP:EquipClient() through the hook HUDWeaponPickedUp
	hook.Add("HUDWeaponPickedUp", "nzu_ClientsideWeaponEquip", function(wep)
		if wep.EquipClient then wep:Equip() end
		hook.Run("WeaponEquip", wep, LocalPlayer())
	end)
end


--[[-------------------------------------------------------------------------
Getters and Utility
	Clientside these only works on LocalPlayer()
---------------------------------------------------------------------------]]
function PLAYER:GetWeaponSlot(slot)
	return self.nzu_WeaponSlots[slot]
end

function PLAYER:GetWeaponInSlot(slot)
	local slot = self:GetWeaponSlot(slot)
	return slot and slot.Weapon
end

function PLAYER:GetWeaponSlotNumber(slot)
	local slot = self:GetWeaponSlot(slot)
	return slot and slot.Number
end

function PLAYER:GetActiveWeaponSlot()
	return self:GetActiveWeapon():GetWeaponSlot()
end
function PLAYER:GetReplaceWeaponSlot()
	for k,v in ipairs(self.nzu_WeaponSlots) do -- ipairs: Only iterate through numerical. It inherently makes it only find "Open" slots! :D
		if not v.Weapon then
			return v.ID
		end
	end

	local wep = self:GetActiveWeapon()
	return IsValid(wep) and wep:GetWeaponSlotNumber() or IsValid(self.nzu_PreviousWeapon) and self.nzu_PreviousWeapon:GetWeaponSlotNumber() or 1
end

function PLAYER:GetMaxWeaponSlots()
	return #self.nzu_WeaponSlots -- Only counts numerical indexes
end


function WEAPON:GetWeaponSlotNumber()
	return self.nzu_WeaponSlot_Number
end

function WEAPON:GetWeaponSlot()
	return self.nzu_WeaponSlot
end



--[[-------------------------------------------------------------------------
Ammo Supply & Calculations (Max Ammo functions)
---------------------------------------------------------------------------]]
-- This can be overwritten by any weapon
local function calculatemaxammo(self)
	if self.CalculateMaxAmmo then return self:CalculateMaxAmmo() end

	local x,y
	if self:GetPrimaryAmmoType() >= 0 then
		local clip = self:GetMaxClip1()
		if clip <= 1 then
			x = 10 -- The amount of ammo for guns that have no mags or single-shot mags
		else
			local upper = self.nzu_UpperPrimaryAmmo or 300
			x = clip * math.Min(10, math.ceil(upper / clip))
		end
	end

	if self:GetSecondaryAmmoType() >= 0 then
		local clip = self:GetMaxClip2()
		if clip <= 1 then
			y = 10 -- The amount of ammo for guns that have no mags or single-shot mags
		else
			local upper = self.nzu_UpperSecondaryAmmo or 300
			y = clip * math.Min(10, math.ceil(upper / clip))
		end
	end

	return x,y
end

if SERVER then
	util.AddNetworkString("nzu_weaponammo") -- Server: Network to weapon owners their holstered weapons' ammo counts when updated while it is holstered
	local function doholsteredammo(wep, num, prim, give)
		if prim then
			wep.nzu_PrimaryAmmo = num
		else
			wep.nzu_SecondaryAmmo = num
		end
		net.Start("nzu_weaponammo")
			net.WriteEntity(wep)
			net.WriteBool(prim)
			net.WriteUInt(num, 16)
			--net.WriteBool(true)
		net.Send(wep.Owner)
	end

	-- This can also be overwritten by any weapon (but wait, can it? D:)
	function WEAPON:GiveMaxAmmo()
		if self.DoMaxAmmo then self:DoMaxAmmo(false) return end

		local primary = self:GetPrimaryAmmoType()
		local secondary = self:GetSecondaryAmmoType()
		if primary >= 0 or secondary >= 0 then
			local x,y = calculatemaxammo(self)

			if x and primary >= 0 then
				local count = self:GetOwner():GetAmmoCount(primary)
				local diff = x - count
				if self:GetOwner():GetActiveWeapon() == self then
					self:GetOwner():GiveAmmo(diff, primary)
				else
					doholsteredammo(self, x, true)
				end
			end

			if y and secondary >= 0 then
				local count = self:GetOwner():GetAmmoCount(secondary)
				local diff = y - count
				if diff > 0 then
					if self:GetOwner():GetActiveWeapon() == self then
						self:GetOwner():GiveAmmo(diff, secondary)
					else
						doholsteredammo(self, y, false)
					end
				end
			end
		end
	end

	function WEAPON:GivePrimaryAmmo(diff)
		local ammo = self:GetPrimaryAmmoType()
		if ammo >= 0 then
			if self:GetOwner():GetActiveWeapon() == self then
				self:GetOwner():GiveAmmo(diff, ammo)
			else
				doholsteredammo(self, self:Ammo1() + diff, true)
			end
		end
	end

	function WEAPON:GiveSecondaryAmmo(diff)
		local ammo = self:GetSecondaryAmmoType()
		if ammo >= 0 then
			if self:GetOwner():GetActiveWeapon() == self then
				self:GetOwner():GiveAmmo(diff, ammo)
			else
				doholsteredammo(self, self:Ammo2() + diff, false)
			end
		end
	end

	function WEAPON:SetMaxAmmo()
		if self.DoMaxAmmo then self:DoMaxAmmo(true) return end

		local primary = self:GetPrimaryAmmoType()
		local secondary = self:GetSecondaryAmmoType()
		if primary >= 0 or secondary >= 0 then
			local x,y = calculatemaxammo(self)

			if x and primary >= 0 then
				if self:GetOwner():GetActiveWeapon() == self then
					self:GetOwner():SetAmmo(x, primary)
				else
					doholsteredammo(self, x, true)
				end
			end

			if y and secondary >= 0 then
				if self:GetOwner():GetActiveWeapon() == self then
					self:GetOwner():SetAmmo(y, secondary)
				else
					doholsteredammo(self, y, false)
				end
			end
		end
	end

	function PLAYER:GiveMaxAmmo()
		for k,v in pairs(self:GetWeapons()) do
			v:GiveMaxAmmo()
		end
	end

	function PLAYER:GiveRoundProgressionAmmo()
		for k,v in pairs(self:GetWeapons()) do
			if v.GiveRoundProgressionAmmo then v:GiveRoundProgressionAmmo() end
		end
	end
	hook.Add("nzu_RoundPrepare", "nzu_Weapons_RoundProgressionAmmo", function()
		for k,v in pairs(nzu.Round:GetPlayers()) do
			v:GiveRoundProgressionAmmo()
		end
	end)
else
	net.Receive("nzu_weaponammo", function()
		local wep = net.ReadEntityQueued()
		local prim = net.ReadBool()
		local num = net.ReadUInt(16)
		--local give = net.ReadBool()

		if IsValid(wep) then
			--local diff = num - (prim and wep.nzu_PrimaryAmmo or wep.nzu_SecondaryAmmo)
			if prim then wep.nzu_PrimaryAmmo = num else wep.nzu_SecondaryAmmo = num end
			--if give then hook.Run("HUDAmmoPickedUp", game.GetAmmoName(prim and wep:GetPrimaryAmmoType() or wep:GetSecondaryAmmoType()), diff) end
		else
			wep:Run(function(w)
				--local diff = num - (prim and wep.nzu_PrimaryAmmo or wep.nzu_SecondaryAmmo)
				if prim then w.nzu_PrimaryAmmo = num else w.nzu_SecondaryAmmo = num end
				--if give then hook.Run("HUDAmmoPickedUp", game.GetAmmoName(prim and w:GetPrimaryAmmoType() or w:GetSecondaryAmmoType()), diff) end
			end)
		end
	end)
end

-- If the weapon is active, its ammo is the player's ammo. Otherwise it's the stored number
function WEAPON:Ammo1()
	return self:GetOwner():GetActiveWeapon() == self and self:GetOwner():GetAmmoCount(self:GetPrimaryAmmoType()) or self.nzu_PrimaryAmmo or self:GetOwner():GetAmmoCount(self:GetPrimaryAmmoType())
end
function WEAPON:Ammo2()
	return self:GetOwner():GetActiveWeapon() == self and self:GetOwner():GetAmmoCount(self:GetSecondaryAmmoType()) or self.nzu_SecondaryAmmo or self:GetOwner():GetAmmoCount(self:GetSecondaryAmmoType())
end



--[[-------------------------------------------------------------------------
Weapon slots adding, removing, and networking
---------------------------------------------------------------------------]]
local specialslots = {} -- Used for Special Slots (later in this file)

local function doweaponslot(ply, wep, slot)
	local wslot = ply:GetWeaponSlot(slot)
	if not wslot then
		wslot = {ID = slot, Weapon = wep}
		ply.nzu_WeaponSlots[slot] = wslot
	end

	wslot.Weapon = wep
	wep.nzu_WeaponSlot = wslot.ID
	wep.nzu_WeaponSlot_Number = wslot.Number

	local id = wslot.ID
	if specialslots[id] then
		local func = wep["SpecialSlot" .. id] or wep["SpecialSlot"] or specialslots[id]
		if func then func(wep, ply, id) end
	end

	-- If the slot can be numerically accessed, auto-switch to it
	if wslot.Number and IsValid(wep) then
		ply:SelectWeaponPredicted(wep)
	end

	hook.Run("nzu_WeaponEquippedInSlot", ply, wep, slot)
end

local function doremoveweapon(ply, wep)
	local slot = wep:GetWeaponSlot()
	if slot then
		local wslot = ply.nzu_WeaponSlots[slot]
		if wslot.Weapon == wep then
			wslot.Weapon = nil
			hook.Run("nzu_WeaponRemovedFromSlot", ply, wep, slot)
		end
	end
end

local function accessweaponslot(self, id, b)
	local slot = self:GetWeaponSlot(id)
	if b then
		if not slot then
			slot = {}
			slot.ID = id
			self.nzu_WeaponSlots[id] = slot
		end
		if not slot.Number then
			slot.Number = table.insert(self.nzu_WeaponSlots, slot)
			if IsValid(slot.Weapon) then slot.Weapon.nzu_WeaponSlot_Number = slot.Number end
		end
	else
		if slot and slot.Number then
			table.remove(self.nzu_WeaponSlots, slot.Number)
			slot.Number = nil
			if IsValid(slot.Weapon) then slot.Weapon.nzu_WeaponSlot_Number = nil end
		end
	end
end

hook.Add("EntityRemoved", "nzu_WeaponRemovedFromSlot", function(ent)
	if ent:IsWeapon() and IsValid(ent:GetOwner()) then
		doremoveweapon(ent:GetOwner(), ent)
	end
end)

if SERVER then
	util.AddNetworkString("nzu_weaponslot")
	util.AddNetworkString("nzu_weaponslot_access")

	-- Override PLAYER:Give so that our NoAmmo argument works with Max Ammo rather than Default Clip
	local oldgive = PLAYER.Give
	function PLAYER:Give(class, noammo)
		local wep = oldgive(self, class, noammo) -- Give the weapon normally. If noammo, then the weapon will also have no ammo from here

		if IsValid(wep) and not noammo then
			wep:SetMaxAmmo()
		end
		return wep
	end

	function PLAYER:StripWeaponSlot(slot)
		local wep = self:GetWeaponInSlot(slot)
		if IsValid(wep) then
			self:StripWeapon(wep:GetClass()) -- It'll auto-remove from the slot
		end
	end

	local function doweaponslotnetwork(ply, wep, slot)
		wep.nzu_OldWeight = wep.Weight
		wep.Weight = math.huge -- Ensure this weapon is always selected!
		ply:StripWeaponSlot(slot)
		doweaponslot(ply, wep, slot)

		net.Start("nzu_weaponslot")
			net.WriteEntity(wep)
			net.WriteString(slot)
		net.Send(ply)
	end
	hook.Add("PostPlayerSwitchWeapon", "nzu_Weapons_RestoreWeight", function(ply, old, new)
		if new.nzu_OldWeight then
			new.Weight = new.nzu_OldWeight
			new.nzu_OldWeight = nil
		end
	end)

	function PLAYER:SetNumericalAccessToWeaponSlot(slot, b)
		accessweaponslot(self, slot, b)

		net.Start("nzu_weaponslot_access")
			net.WriteString(slot)
			net.WriteBool(b)
		net.Send(self)
	end

	function PLAYER:GiveWeaponInSlot(class, slot, noammo)
		local wep = self:Give(class, noammo)
		if IsValid(wep) then doweaponslotnetwork(self, wep, slot) end
		return wep
	end

	hook.Add("WeaponEquip", "nzu_WeaponPickedUp", function(wep, ply)
		timer.Simple(0, function()
			if IsValid(wep) and IsValid(ply) and not wep.nzu_WeaponSlot then
				local slot = wep.nzu_DefaultWeaponSlot or ply:GetReplaceWeaponSlot()
				doweaponslotnetwork(ply, wep, slot)
				--ply:SelectWeapon(wep:GetClass()) -- This a dumb idea with prediction?
			end
		end)
	end)
else
	net.Receive("nzu_weaponslot", function()
		local i = net.ReadUInt(16) -- Same as net.ReadEntity()
		local wep = Entity(i)
		local slot = net.ReadString()

		if IsValid(wep) then
			doweaponslot(LocalPlayer(), wep, slot)
		else -- If we get networking before the entity is valid, keep an eye out for when it should be ready
			hook.Add("WeaponEquip", "nzu_WeaponSlot" .. slot, function(wep)
				if wep:EntIndex() == i then
					doweaponslot(LocalPlayer(), wep, slot)
					hook.Remove("WeaponEquip", "nzu_WeaponSlot" .. slot)
				end
			end)
		end
	end)

	net.Receive("nzu_weaponslot_access", function()
		local slot = net.ReadString()
		local b = net.ReadBool()
		accessweaponslot(LocalPlayer(), slot, b)
	end)
end



--[[-------------------------------------------------------------------------
Weapon Switching + Ammo management
---------------------------------------------------------------------------]]
local keybinds = {}
function nzu.AddKeybindToWeaponSlot(slot, key)
	keybinds[key] = slot
end

local maxswitchtime = 3
function PLAYER:SelectWeaponPredicted(wep)
	self.nzu_DoSelectWeapon = wep
	self.nzu_DoSelectWeaponTime = CurTime() + maxswitchtime
end

-- Select the weapon, but mark it as a Special deploy
function PLAYER:SpecialSelectWeaponPredicted(wep)
	local w = self.nzu_DoSelectWeaponSpecial
	if IsValid(w) and w ~= wep then
		if w.nzu_NonSpecialDeploy then
			w.Deploy = w.nzu_NonSpecialDeploy
			w.nzu_NonSpecialDeploy = nil
		end
		w.nzu_IsSpecialDeployed = nil
	end

	self:SelectWeaponPredicted(wep)
	self.nzu_DoSelectWeaponSpecial = wep
	wep.nzu_IsSpecialDeployed = true

	if wep.SpecialDeploy then
		wep.nzu_NonSpecialDeploy = wep.Deploy
		function wep:Deploy()
			self:SpecialDeploy()
		end
	end
end

hook.Add("PlayerButtonDown", "nzu_WeaponSwitching_Keybinds", function(ply, but)
	-- Buttons 1-10 are keys 0-9
	local slot = keybinds[but]
	if slot then
		-- It is a keybind (special slot)
		local wep = ply:GetWeaponInSlot(slot)
		if IsValid(wep) and (not wep.CanSpecialDeploy or wep:CanSpecialDeploy()) then
			wep.nzu_SpecialKeyDown = but
			if IsValid(ply.nzu_SpecialWeapon) then ply.nzu_SpecialWeapon.nzu_SpecialKeyDown = nil end -- Can only use 1 at a time, to make things simple
			ply.nzu_SpecialKeyDown = but
			ply.nzu_SpecialWeapon = wep

			ply:SpecialSelectWeaponPredicted(wep)
		end


	else
		slot = but < 11 and but - 1

		-- What? MOUSE_WHEEL_ doesn't work even though it's within the enum??? D:
		--[[if not slot then

			print("Not numerical or keybound", but)
			if but == MOUSE_WHEEL_UP then
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) and wep:GetWeaponSlotNumber() then
					slot = wep:GetWeaponSlotNumber() + 1
					if slot > ply:GetMaxWeaponSlots() then slot = 1 end
				end
			elseif but == MOUSE_WHEEL_DOWN then
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) and wep:GetWeaponSlotNumber() then
					slot = wep:GetWeaponSlotNumber() - 1
					if slot < 0 then slot = ply:GetMaxWeaponSlots() end
				end
			end
		end]]

		if slot then
			local wep = ply:GetWeaponInSlot(slot)
			if IsValid(wep) then
				ply:SelectWeaponPredicted(wep)
			end
		end
	end
end)

hook.Add("PlayerButtonUp", "nzu_WeaponSwitching_Keybinds", function(ply, but)
	if ply.nzu_SpecialKeyDown == but then
		local w = ply.nzu_SpecialWeapon
		if IsValid(w) then
			w.nzu_SpecialKeyDown = nil
			if w.SpecialKeyReleased then w:SpecialKeyReleased() end
		end

		ply.nzu_SpecialKeyDown = nil
		ply.nzu_SpecialWeapon = nil
	end
end)

function WEAPON:SpecialKeyDown()
	return self.nzu_SpecialKeyDown
end

function WEAPON:IsSpecialDeployed()
	return self.nzu_IsSpecialDeployed
end

hook.Add("StartCommand", "nzu_WeaponSwitching", function(ply, cmd)
	-- if PlayerButtonDown won't work, we gotta do it here :(
	local wep = ply:GetActiveWeapon()
	if ply:Alive() then
		if not ply.nzu_DoSelectWeapon then
			local m = cmd:GetMouseWheel()
			if m ~= 0 then
				local slot = (IsValid(wep) and wep:GetWeaponSlotNumber() or 0) + m

				local max = ply:GetMaxWeaponSlots()
				if slot > max then slot = 1 elseif slot < 1 then slot = max end

				local wep2 = ply:GetWeaponInSlot(slot)
				if IsValid(wep2) then
					ply:SelectWeaponPredicted(wep2)
				end
			end
		else
			if wep == ply.nzu_DoSelectWeapon or CurTime() > ply.nzu_DoSelectWeaponTime then
				ply.nzu_DoSelectWeapon = nil
				ply.nzu_DoSelectWeaponTime = nil
			else
				cmd:SelectWeapon(ply.nzu_DoSelectWeapon)
			end
		end
	end

	if wep ~= ply.nzu_LastActiveWeapon then
		local w2 = ply.nzu_LastActiveWeapon
		ply.nzu_LastActiveWeapon = wep

		-- If we have a special selected weapon and we switch to any OTHER weapon, reset this special one
		local w = ply.nzu_DoSelectWeaponSpecial
		if w and w ~= wep then
			if IsValid(w) then
				if w.nzu_NonSpecialDeploy then
					w.Deploy = w.nzu_NonSpecialDeploy
					w.nzu_NonSpecialDeploy = nil
				end
				w.nzu_IsSpecialDeployed = nil
			end
			ply.nzu_DoSelectWeaponSpecial = nil
		end

		hook.Run("PostPlayerSwitchWeapon", ply, w2, wep)
	end
end)






--[[-------------------------------------------------------------------------
Special weapon slot behavior
---------------------------------------------------------------------------]]
nzu.AddPlayerNetworkVar("Entity", "WeaponLocked") -- When set to a weapon, you cannot switch weapons unless it is to this one
-- When you use this, make sure to also switch to it yourself; it will not auto-switch to the selected weapon

function nzu.SpecialWeaponSlot(id, func)
	specialslots[id] = func
end

function PLAYER:SelectPreviousWeapon()
	local wep = self.nzu_PreviousWeapon
	if not IsValid(wep) then wep = self:GetWeaponInSlot(1) end
	if IsValid(wep) then
		self.nzu_DoSelectWeapon = wep
		self.nzu_DoSelectWeaponTime = CurTime() + maxswitchtime

		-- Swap the two
		self.nzu_PreviousWeapon = self.nzu_PreviousWeapon2
		self.nzu_PreviousWeapon2 = wep
	end
end

if SERVER then
	-- Handle restoring ammo counts
	-- This simulates separate weapon slots having separate ammo, even if they should share type
	function GM:PostPlayerSwitchWeapon(ply, old, new)
		if IsValid(old) then
			local primary = old:GetPrimaryAmmoType()
			if primary >= 0 then old.nzu_PrimaryAmmo = ply:GetAmmoCount(primary) end

			local secondary = old:GetSecondaryAmmoType()
			if secondary >= 0 then old.nzu_SecondaryAmmo = ply:GetAmmoCount(secondary) end
		end

		if IsValid(new) then
			if new.nzu_PrimaryAmmo then ply:SetAmmo(new.nzu_PrimaryAmmo, new:GetPrimaryAmmoType()) end
			if new.nzu_SecondaryAmmo then ply:SetAmmo(new.nzu_SecondaryAmmo, new:GetSecondaryAmmoType()) end
		end
	end

	hook.Add("PlayerSpawn", "nzu_Weapons_Unlock", function(ply) ply:SetWeaponLocked(nil) end)
else
	-- Clients just need to predict their own values when holstered. They are only updated from the server when ammo is set while the weapon is already holstered
	function GM:PostPlayerSwitchWeapon(ply, old, new)
		if IsValid(old) then
			local primary = old:GetPrimaryAmmoType()
			if primary >= 0 then old.nzu_PrimaryAmmo = ply:GetAmmoCount(primary) end

			local secondary = old:GetSecondaryAmmoType()
			if secondary >= 0 then old.nzu_SecondaryAmmo = ply:GetAmmoCount(secondary) end
		end
	end
end

-- Track old weapons and handle blocking of switching based on special slots
function GM:PlayerSwitchWeapon(ply, old, new)
	local w = ply:GetWeaponLocked()
	if IsValid(w) and w ~= new then return true end -- If we have a locked weapon and we aren't switching to that
	if new.PreventDeploy and new:PreventDeploy() then return true end -- If the new weapon implements PreventDeploy

	if IsValid(old) then
		if old:GetWeaponSlotNumber() then
			if ply.nzu_PreviousWeapon ~= old then
				ply.nzu_PreviousWeapon2 = ply.nzu_PreviousWeapon
				ply.nzu_PreviousWeapon = old
			end
		end
	end
end

-- HUD registration
if CLIENT then
	local hudweapons = {}
	hook.Add("nzu_WeaponEquippedInSlot", "nzu_Weapons_HUDWeapon", function(ply, wep, slot)
		local bind
		for k,v in pairs(keybinds) do
			if v == slot then
				bind = input.GetKeyName(k)
				break
			end
		end

		if wep.DrawHUDIcon then table.insert(hudweapons, {Weapon = wep, Bind = bind}) end
	end)

	hook.Add("nzu_WeaponRemovedFromSlot", "nzu_Weapons_HUDWeapon", function(ply, wep, slot)
		for k,v in pairs(hudweapons) do
			if v.Weapon == wep then
				table.remove(hudweapons, k)
				return
			end
		end
	end)

	nzu.HUDComponent("Weapons", function() return hudweapons end)
end

--[[-------------------------------------------------------------------------
Populate base weapon slots
---------------------------------------------------------------------------]]

nzu.AddKeybindToWeaponSlot("Knife", KEY_V)
nzu.AddKeybindToWeaponSlot("Grenade", KEY_G)
nzu.AddKeybindToWeaponSlot("SpecialGrenade", KEY_B)

local function defaultkeybindattack(self)
	self.IsAttacking = true

	self:SetNextPrimaryFire(0)
	self:PrimaryFire()

	timer.Simple(0.5, function()
		if IsValid(self) then
			local vm = self:GetOwner():GetViewModel()
			local seq = vm:GetSequence()
			local dur = vm:SequenceDuration(seq)
			local remaining = dur - dur*vm:GetCycle()
			timer.Simple(remaining, function()
				if IsValid(self) then
					self.IsAttacking = nil
					self:GetOwner():SelectPreviousWeapon()
				end
			end)
		end
	end)
end
local function defaultmodify(wep)
	if not wep.SpecialDeploy then
		wep.SpecialDeploy = defaultkeybindattack

		local oldholster = wep.Holster
		wep.Holster = function(self)
			return not self.IsAttacking and oldholster(self)
		end
	end
end

nzu.SpecialWeaponSlot("Knife", function(wep)
	defaultmodify(wep)
	wep.nzu_InstantDeploy = true -- Knives will additionally have instant deploy on
end)
nzu.SpecialWeaponSlot("Grenade", function(wep)
	defaultmodify(wep)

	-- Grenades will additionally auto-modify round progression ammo
	if not wep.GiveRoundProgressionAmmo then
		wep.AmmoPerRound = 2
		wep.GrenadeMax = 4
		wep.GiveRoundProgressionAmmo = weapons.GetStored("nzu_grenade_mk3a2").GiveRoundProgressionAmmo
	end
end, true)

nzu.SpecialWeaponSlot("SpecialGrenade", defaultmodify, true)



--[[-------------------------------------------------------------------------
Instant deploying for all weapons, if the target weapon has nzu_InstantDeploy true
We use this with knives to make them instantly attack, regardless of holster animations/functions
---------------------------------------------------------------------------]]
hook.Add("nzu_WeaponEquippedInSlot", "nzu_Weapons_InstantHolsterFunction", function(ply, wep, slot)
	local old = wep.Holster
	function wep:Holster(w2)
		if w2.nzu_InstantDeploy then old(self, w2) return true end
		return old(self, w2)
	end
end)



--[[-------------------------------------------------------------------------
Weighted Weapon List utility functions
These functions let you determine random weapons for players from a pool of weighted weapons
It also supports it such that weapons the player is already carrying are not selected
---------------------------------------------------------------------------]]

if SERVER then 
	-- Select a weapon from a weighted weapon list (Table where key is classname, value is numerical weight)
	-- If ply is passed, that player's weapons are filtered out. If not, it takes from the full pool.
	function nzu.SelectWeapon(pool, ply)
		if pool[1] then
			local possible = IsValid(ply) and nzu.FilterWeaponListForPlayer(pool, ply) or pool
			return possible[math.random(#possible)]
		else
			local possible
			local total = 0

			if IsValid(ply) then
				possible, total = nzu.FilterWeaponListForPlayer(pool, ply)
			else
				possible = pool
				for k,v in pairs(possible) do
					total = total + v
				end
			end

			local ran = math.random(total)
			local cur = 0
			for k,v in pairs(possible) do
				cur = cur + v
				if cur >= ran then
					return k
				end
			end
		end
	end

	-- Filters a weapon list for the specified player. This removes all weapons the player is already carrying.
	-- If the list is weighted, a total is returned as the second argument
	function nzu.FilterWeaponListForPlayer(pool, ply)
		local possible = {}
		if pool[1] then -- Sequential
			for k,v in pairs(pool) do
				if not IsValid(ply:GetWeapon(v)) then
					table.insert(possible, v)
				end
			end
			return possible
		else
			local total = 0
			for k,v in pairs(pool) do
				if not IsValid(ply:GetWeapon(k)) then
					possible[k] = v
					total = total + v
				end
			end
			return possible, total
		end
	end

	-- Precache world and view model of all weapons in the list
	-- This is networked to all clients. If "ply" is passed, it is only networked to that player or table of players (net.Send-supported argument)
	util.AddNetworkString("nzu_precacheweapons")
	function nzu.NetworkPrecacheWeaponModels(weps, ply)
		net.Start("nzu_precacheweapons")
			local num = table.Count(weps)
			net.WriteUInt(num, 16)

			if weps[1] then -- It is numerically sequential (presumably!)
				for k,v in pairs(weps) do
					net.WriteString(v)
				end
			else -- If it is class-based on keys (such as a weighted weapon list)
				for k,v in pairs(weps) do
					net.WriteString(k)
				end
			end
		if ply then net.Send(ply) else net.Broadcast() end
	end
else

	-- Clientside: Precache the weapon(s). util.PrecacheModel doesn't quite work, instead we draw it using a clientside model
	function nzu.PrecacheWeaponModels(weps)
		local cmodel
		for k,v in pairs(weps) do
			local wep = weapons.GetStored(v)
			if wep then
				local model = wep.WM or wep.WorldModel
				if model and model ~= "" then
					util.PrecacheModel(model)
					if not cmodel then cmodel = ClientsideModel(model) else cmodel:SetModel(model) end
					--print("Precaching:", model)
					cmodel:DrawModel()
				end
				local model2 = wep.VM or wep.ViewModel
				if model2 and model2 ~= "" then
					util.PrecacheModel(model2)
					if not cmodel then cmodel = ClientsideModel(model2) else cmodel:SetModel(model2) end
					--print("Precaching:", model2)
					cmodel:DrawModel()
				end
			end
		end
		if cmodel then cmodel:Remove() end
	end

	net.Receive("nzu_precacheweapons", function()
		local t = {}
		local num = net.ReadUInt(16)
		for i = 1,num do
			table.insert(t, net.ReadString())
		end

		nzu.PrecacheWeaponModels(t)
	end)
end