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
	for k,v in ipairs(self.nzu_WeaponSlots) do
		if not v.Weapon then
			return k
		end
	end
	return self:GetActiveWeaponSlot()
end


function WEAPON:GetWeaponSlotNumber()
	return self.nzu_WeaponSlot_Number
end

function WEAPON:GetWeaponSlot()
	return self.nzu_WeaponSlot
end




--[[-------------------------------------------------------------------------
Adding and removing + Networking
---------------------------------------------------------------------------]]
local function doweaponslot(ply, wep, slot)
	local wslot = ply:GetWeaponSlot(slot)
	if not wslot then
		wslot = {ID = slot, Weapon = wep}
		ply.nzu_WeaponSlots[slot] = wslot
	end
	wep.nzu_WeaponSlot = wslot.ID
	wep.nzu_WeaponSlot_Number = wslot.Number
end

local function doremoveweapon(ply, wep)
	if wep:GetWeaponSlot() then
		local slot = ply.nzu_WeaponSlots[wep:GetWeaponSlot()]
		slot.Weapon = nil
	end
end

local function accessweaponslot(self, slot, b)
	local slot = self:GetWeaponSlot(slot)
	if b then
		if not slot then
			slot = {}
			self.nzu_WeaponSlots[slot] = slot
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

	function PLAYER:GiveWeaponInSlot(class, slot)
		local wep = self:Give(class)
		if IsValid(wep) then doweaponslotnetwork(wep, slot) end
	end

	hook.Add("WeaponEquip", "nzu_WeaponPickedUp", function(wep, ply)
		timer.Simple(0, function()
			if IsValid(wep) and IsValid(ply) and not wep.nzu_WeaponSlot then
				local slot = ply:GetReplaceWeaponSlot()
				doweaponslotnetwork(wep, slot)
				ply:SelectWeapon(wep:GetClass()) -- This a dumb idea with prediction?
			end
		end)
	end)

	function PLAYER:StripWeaponSlot(slot)
		local wep = self:GetWeaponInSlot(slot)
		if IsValid(wep) then
			self:StripWeapon(wep:GetClass()) -- It'll auto-remove from the slot
		end
	end
else
	net.Receive("nzu_weaponslot", function()
		local wep = net.ReadEntity()
		local slot = net.ReadString()
		doweaponslot(LocalPlayer(), wep, slot)
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

hook.Add("PlayerButtonDown", "nzu_WeaponSwitching_Keybinds", function(ply, but)
	-- Buttons 1-10 are keys 0-9
	local slot = but < 11 and but - 1 or keybinds[but]
	if slot then
		local wep = ply:GetWeaponInSlot(slot)
		if IsValid(wep) then
			ply.nzu_DoWeaponSwitch = wep
		end
	end
end)

hook.Add("SetupMove", "nzu_WeaponSwitching", function(ply, mv, cmd)
	if cmd:KeyDown(IN_WEAPON1) then -- Scroll wheel up
		
	elseif cmd:KeyDown(IN_WEAPON2) then -- Scroll wheel down
		
	end
end)

if SERVER then
	-- Handle restoring ammo counts
	-- This simulates separate weapon slots having separate ammo, even if they should share type
	function GM:PlayerSwitchWeapon(ply, old, new)
		if IsValid(old) then
			local primary = old:GetPrimaryAmmoType()
			if primary then old.nzu_PrimaryAmmo = ply:GetAmmoCount(primary) end

			local secondary = old:GetSecondaryAmmoType()
			if secondary then old.nzu_SecondaryAmmo = ply:GetAmmoCount(secondary) end
		end

		if IsValid(new) then
			if new.nzu_PrimaryAmmo then ply:SetAmmo(new.nzu_PrimaryAmmo, new:GetPrimaryAmmoType()) end
			if new.nzu_SecondaryAmmo then ply:SetAmmo(new.nzu_SecondaryAmmo, new:GetSecondaryAmmoType()) end
		end
	end
end