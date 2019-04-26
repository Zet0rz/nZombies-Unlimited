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

	if CLIENT then
		ply.nzu_HUDWeapons = {}
	end
end
if SERVER then
	hook.Add("PlayerInitialSpawn", "nzu_WeaponSlotsInit", doinitialize)
else
	hook.Add("InitPostEntity", "nzu_WeaponSlotsInit", function() doinitialize(LocalPlayer()) end)
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

function PLAYER:GetActiveWeaponSlot()
	return self:GetActiveWeapon():GetWeaponSlot()
end
function PLAYER:GetReplaceWeaponSlot()
	for k,v in ipairs(self.nzu_WeaponSlots) do -- ipairs: Only iterate through numerical. It inherently makes it only find "Open" slots! :D
		if not v.Weapon then
			return v.ID
		end
	end
	return self:GetActiveWeaponSlot()
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
if SERVER then
	-- This can be overwritten by any weapon
	local function calculatemaxammo(self)
		local x,y
		if self:GetPrimaryAmmoType() >= 0 then
			local clip = self:GetMaxClip1()
			if clip <= 1 then
				x = 10 -- The amount of ammo for guns that have no mags or single-shot mags
			else
				local upper = self.nzu_UpperPrimaryAmmo or 300
				x = clip * math.Min(10, math.ceil(upper/clip))
			end
		end

		if self:GetSecondaryAmmoType() >= 0 then
			local clip = self:GetMaxClip2()
			if clip <= 1 then
				y = 10 -- The amount of ammo for guns that have no mags or single-shot mags
			else
				local upper = self.nzu_UpperSecondaryAmmo or 300
				y = clip * math.Min(10, math.ceil(upper/clip))
			end
		end

		return x,y
	end

	-- This can also be overwritten by any weapon (but wait, can it? D:)
	function WEAPON:GiveMaxAmmo()
		if self.DoMaxAmmo then self:DoMaxAmmo() return end

		local primary = self:GetPrimaryAmmoType()
		local secondary = self:GetSecondaryAmmoType()
		if primary >= 0 or secondary >= 0 then
			local x,y
			if self.CalculateMaxAmmo then x,y = self:CalculateMaxAmmo() else x,y = calculatemaxammo(self) end

			if x and primary >= 0 then
				local count = self.Owner:GetAmmoCount(primary)
				local diff = x - count
				if diff > 0 then
					self.Owner:GiveAmmo(diff, primary)

					if self.Owner:GetActiveWeapon() ~= self then
						self.nzu_PrimaryAmmo = x
					end
				end
			end

			if y and secondary >= 0 then
				local count = self.Owner:GetAmmoCount(secondary)
				local diff = y - count
				if diff > 0 then
					self.Owner:GiveAmmo(diff, secondary)

					if self.Owner:GetActiveWeapon() ~= self then
						self.nzu_SecondaryAmmo = y
					end
				end
			end
		end
	end

	function PLAYER:GiveMaxAmmo()
		for k,v in pairs(self:GetWeapons()) do
			v:GiveMaxAmmo()
		end
	end
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

	if specialslots[wslot.ID] then
		local func = wep["SpecialSlot"..wslot.ID] or specialslots[wslot.ID]
		if func then func(wep, ply) end
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
		wslot.Weapon = nil

		hook.Run("nzu_WeaponRemovedFromSlot", ply, wep, slot)
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
			wep:GiveMaxAmmo()
		end
	end

	function PLAYER:StripWeaponSlot(slot)
		local wep = self:GetWeaponInSlot(slot)
		if IsValid(wep) then
			self:StripWeapon(wep:GetClass()) -- It'll auto-remove from the slot
		end
	end

	local function doweaponslotnetwork(ply, wep, slot)
		ply:StripWeaponSlot(slot)
		doweaponslot(ply, wep, slot)

		net.Start("nzu_weaponslot")
			net.WriteEntity(wep)
			net.WriteString(slot)
		net.Send(ply)
	end

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
			hook.Add("HUDWeaponPickedUp", "nzu_WeaponSlot"..slot, function(wep)
				if wep:EntIndex() == i then
					doweaponslot(LocalPlayer(), wep, slot)
					hook.Remove("HUDWeaponPickedUp", "nzu_WeaponSlot"..slot)
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

hook.Add("PlayerButtonDown", "nzu_WeaponSwitching_Keybinds", function(ply, but)
	-- Buttons 1-10 are keys 0-9
	local slot = but < 11 and but - 1 or keybinds[but]

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

	if but == KEY_Q then
		ply:SelectPreviousWeapon()
	elseif slot then
		local wep = ply:GetWeaponInSlot(slot)
		if IsValid(wep) then
			ply:SelectWeaponPredicted(wep)
			ply.nzu_SpecialKeyDown = but
		end
	end
end)

hook.Add("PlayerButtonUp", "nzu_WeaponSwitching_Keybinds", function(ply, but)
	if ply.nzu_SpecialKeyDown == but then ply.nzu_SpecialKeyDown = nil end
end)

function WEAPON:IsSpecialSlotKeyStillDown()
	return self.Owner.nzu_SpecialKeyDown and keybinds[self.Owner.nzu_SpecialKeyDown] == self:GetWeaponSlot()
end

hook.Add("StartCommand", "nzu_WeaponSwitching", function(ply, cmd)
	-- if PlayerButtonDown won't work, we gotta do it here :(
	if not ply.nzu_DoSelectWeapon then
		local m = cmd:GetMouseWheel()
		if m ~= 0 then
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) then
				local slot = (wep:GetWeaponSlotNumber() or 0) + m

				local max = ply:GetMaxWeaponSlots()
				if slot > max then slot = 1 elseif slot < 1 then slot = max end

				local wep2 = ply:GetWeaponInSlot(slot)
				if IsValid(wep2) then
					ply:SelectWeaponPredicted(wep2)
				end
			end
		end
	end

	if ply.nzu_DoSelectWeapon then
		if ply:GetActiveWeapon() == ply.nzu_DoSelectWeapon or CurTime() > ply.nzu_DoSelectWeaponTime then
			ply.nzu_DoSelectWeapon = nil
			ply.nzu_DoSelectWeaponTime = nil
		else
			cmd:SelectWeapon(ply.nzu_DoSelectWeapon)
		end
	end
end)






--[[-------------------------------------------------------------------------
Special weapon slot behavior
---------------------------------------------------------------------------]]
nzu.AddPlayerNetworkVar("Bool", "WeaponLocked") -- When true you can't switch weapons

function nzu.SpecialWeaponSlot(id, func)
	if hud and not specialslots[id] then
		table.insert(specialslothud, id)
	end
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

	-- Also handle special weapon locking
	function GM:PlayerSwitchWeapon(ply, old, new)
		if (ply:GetWeaponLocked() and not old.nzu_CanSpecialHolster) or (new.PreventDeploy and new:PreventDeploy()) then return true end -- Prevent switching when lock is true
		-- Is SWEP:Holster() still called in the above?

		if IsValid(old) then
			local primary = old:GetPrimaryAmmoType()
			if primary >= 0 then old.nzu_PrimaryAmmo = ply:GetAmmoCount(primary) end

			local secondary = old:GetSecondaryAmmoType()
			if secondary >= 0 then old.nzu_SecondaryAmmo = ply:GetAmmoCount(secondary) end

			-- Store old weapons, but ONLY if they are accessible (by number)
			if old:GetWeaponSlotNumber() then
				ply.nzu_PreviousWeapon2 = ply.nzu_PreviousWeapon
				ply.nzu_PreviousWeapon = old
			end
		end

		if IsValid(new) then
			if new.nzu_PrimaryAmmo then ply:SetAmmo(new.nzu_PrimaryAmmo, new:GetPrimaryAmmoType()) end
			if new.nzu_SecondaryAmmo then ply:SetAmmo(new.nzu_SecondaryAmmo, new:GetSecondaryAmmoType()) end
		end
	end
else
	-- Stripped down Client version only really needs to track old weapons
	function GM:PlayerSwitchWeapon(ply, old, new)
		if (ply:GetWeaponLocked() and not old.nzu_CanSpecialHolster) or (new.PreventDeploy and new:PreventDeploy()) then return true end

		if IsValid(old) then
			if old:GetWeaponSlotNumber() then
				ply.nzu_PreviousWeapon2 = ply.nzu_PreviousWeapon
				ply.nzu_PreviousWeapon = old
			end
		end
	end
end

-- HUD registration
if CLIENT then
	hook.Add("nzu_WeaponEquippedInSlot", "nzu_Weapons_HUDWeapon", function(ply, wep, slot)
		local bind
		for k,v in pairs(keybinds) do
			if v == slot then
				bind = input.GetKeyName(k)
				break
			end
		end

		if wep.DrawHUDIcon then table.insert(ply.nzu_HUDWeapons, {Weapon = wep, Bind = bind}) end
	end)

	hook.Add("nzu_WeaponRemovedFromSlot", "nzu_Weapons_HUDWeapon", function(ply, wep, slot)
		for k,v in pairs(ply.nzu_HUDWeapons) do
			if v.Weapon == wep then
				table.remove(ply.nzu_HUDWeapons, k)
				return
			end
		end
	end)
end

--[[-------------------------------------------------------------------------
Populate base weapon slots
---------------------------------------------------------------------------]]

nzu.AddKeybindToWeaponSlot("Knife", KEY_V)
if true then
	nzu.SpecialWeaponSlot("Knife", function(wep)
		wep.OldDeploy = wep.Deploy

		wep.Deploy = function(self)
			self.Owner:SetWeaponLocked(true)
			self:SetNextPrimaryFire(0)
			self:PrimaryFire()
			timer.Simple(0.5, function()
				if IsValid(self) then
					local vm = self.Owner:GetViewModel()
					local seq = vm:GetSequence()
					local dur = vm:SequenceDuration(seq)
					local remaining = dur - dur*vm:GetCycle()
					timer.Simple(remaining, function()
						if IsValid(self) then
							self.Owner:SetWeaponLocked(false)
							self.Owner:SelectPreviousWeapon()
						end
					end)
				end
			end)
		end
	end)
end

nzu.AddKeybindToWeaponSlot("Grenade", KEY_G)
if true then
	nzu.SpecialWeaponSlot("Grenade", function(wep)
		wep.OldDeploy = wep.Deploy

		wep.Deploy = function(self)
			self.Owner:SetWeaponLocked(true)
			self:SetNextPrimaryFire(0)
			self:PrimaryFire()
			timer.Simple(0.5, function()
				if IsValid(self) then
					local vm = self.Owner:GetViewModel()
					local seq = vm:GetSequence()
					local dur = vm:SequenceDuration(seq)
					local remaining = dur - dur*vm:GetCycle()
					timer.Simple(remaining, function()
						if IsValid(self) then
							self.Owner:SetWeaponLocked(false)
							self.Owner:SelectPreviousWeapon()
						end
					end)
				end
			end)
		end
	end, true)
end

nzu.AddKeybindToWeaponSlot("SpecialGrenade", KEY_B)
if true then
	nzu.SpecialWeaponSlot("SpecialGrenade", function(wep)
		wep.OldDeploy = wep.Deploy

		wep.Deploy = function(self)
			self.Owner:SetWeaponLocked(true)
			self:SetNextPrimaryFire(0)
			self:PrimaryFire()
			timer.Simple(0.5, function()
				if IsValid(self) then
					local vm = self.Owner:GetViewModel()
					local seq = vm:GetSequence()
					local dur = vm:SequenceDuration(seq)
					local remaining = dur - dur*vm:GetCycle()
					timer.Simple(remaining, function()
						if IsValid(self) then
							self.Owner:SetWeaponLocked(false)
							self.Owner:SelectPreviousWeapon()
						end
					end)
				end
			end)
		end
	end, true)
end



--[[-------------------------------------------------------------------------
Instant deploying for all weapons, if the target weapon has nzu_InstantDeploy true
We use this with knives to make them instantly attack, regardless of holster animations/functions
---------------------------------------------------------------------------]]
hook.Add("nzu_WeaponEquippedInSlot", "nzu_Weapons_InstantHolsterFunction", function(ply, wep, slot)
	local old = wep.Holster
	function wep:Holster(w2)
		if w2.nzu_InstantDeploy then return true end
		return old(self, w2)
	end
end)