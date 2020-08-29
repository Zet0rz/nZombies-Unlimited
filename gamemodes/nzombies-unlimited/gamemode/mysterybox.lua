
game.AddParticles("particles/mysterybox.pcf")
PrecacheParticleSystem("mysterybox_beam")
PrecacheParticleSystem("mysterybox_roll")

local SETTINGS = nzu.GetExtension("core")
local weaponpool -- The table of weapons. This will be the settings if it is non-empty, otherwise it will be a base generated list from installed weapons
local weaponmodels -- Cache of the list of world models for each weapon

local function reloadweaponmodels(weps)
	weaponmodels = {}
	for k,v in pairs(weps) do
		local wep = weapons.GetStored(k)
		if wep then
			local model = wep.WM or wep.WorldModel
			if model and model ~= "" then
				table.insert(weaponmodels, model)
			end
		end
	end

	-- Network for clients what weapons we currently have in the pool
	nzu.NetworkPrecacheWeaponModels(weps)
end

local function getbaseweapons()
	local baseweapons = {}
	for k,v in pairs(weapons.GetList()) do
		local wep = weapons.Get(v.ClassName)
		if wep and wep.Spawnable and not wep.nzu_PreventBox and not wep.NZPreventBox then
			local model = wep.WM or wep.WorldModel
			if model and model ~= "" then
				baseweapons[v.ClassName] = 1
			end
		end
	end
	return baseweapons
end

function nzu.GetMysteryBoxWeaponPool()
	return weaponpool
end

function nzu.GetMysteryBoxModelPool()
	return weaponmodels
end

function nzu.ReloadMysteryBoxWeaponPool()
	weaponpool = table.IsEmpty(SETTINGS.MysteryBoxWeapons) and getbaseweapons() or SETTINGS.MysteryBoxWeapons
	reloadweaponmodels(weaponpool) -- Reload model list to the weapon pool
end
SETTINGS.OnMysteryBoxWeaponsChanged = nzu.ReloadMysteryBoxWeaponPool -- Reload the weapons whenever the setting is changed
--nzu.ReloadMysteryBoxWeaponPool() -- Also reload to begin with

-- Get the mystery box pool for a specific player. This runs a hook to allow manipulation
function nzu.GetMysteryBoxWeaponPoolFor(ply)
	local t = {}
	for k,v in pairs(nzu.GetMysteryBoxWeaponPool()) do
		t[k] = v
	end

	hook.Run("nzu_MysteryBox_ModifyWeaponTableForPlayer", t, ply) -- Allow a hook to modify the weapons table
	return t -- This is unfiltered! The filtering is done in nzu.SelectWeapon (in the Windup class)
end

-- Create a Mystery Box at a spawnpoint, returns the box entity if the spawnpoint was free!
-- Note that this creates an ADDITIONAL box! The old one moves around as it does. If you want to REPLACE, then remember to remove the other one(s)!
-- If spawnpoint is passed, it spawns at that point. Otherwise it spawns at a random one.
-- You can also pass a position and angle. In this case "spawnpoint" is the position, ang is the angle. It will appear on this position regardless of spawnpoint.
function nzu.CreateMysteryBox(spawnpoint, ang)
	local point = spawnpoint or nzu.GetRandomAvailableMysteryBoxSpawnpoint()
	if IsValid(point) and IsValid(point:GetMysteryBox()) then return end

	local e = ents.Create("nzu_mysterybox")
	--e:Spawn()
	e:Appear(point, ang) -- Pass ang if you want to spawn it on a position (which also then needs an angle)
	return e
end

function nzu.GetAllMysteryBoxSpawnpoints()
	return ents.FindByClass("nzu_mysterybox_spawnpoint") -- This can be changed later in case of sub-classes? Depends on how box skins should work
end

function nzu.GetRandomAvailableMysteryBoxSpawnpoint(list)
	local t = list or nzu.GetAllMysteryBoxSpawnpoints()
	if #t > 0 then
		local points = {}
		for k,v in pairs(t) do
			if IsValid(v) and not IsValid(v:GetMysteryBox()) and not IsValid(v.ReservedBox) then -- All spawnpoints not blocked, not having a box currently, and not being reserved
				table.insert(points, v)
			end
		end

		local num = #points
		if num > 0 then
			return points[math.random(num)]
		end
	end
end

-- Spawn the box when the map is reloaded! :D
hook.Add("nzu_PostConfigMap", "nzu_MysteryBox_Initialize", function()
	local points = nzu.GetAllMysteryBoxSpawnpoints()
	local possible = {}
	for k,v in pairs(points) do
		if v:GetIsPossibleSpawn() then table.insert(possible, v) end
	end

	if #possible < 1 then possible = points end -- None marked for initial spawn, just use all instead
	local point = possible[math.random(#possible)]
	if IsValid(point) then
		nzu.CreateMysteryBox(point)
	end
end)