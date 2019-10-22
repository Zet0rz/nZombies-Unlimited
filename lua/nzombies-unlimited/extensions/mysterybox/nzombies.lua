-- Include the Entities
include("mysterybox_entities.lua")

local EXT = nzu.Extension()
local Settings = EXT.Settings

game.AddParticles("particles/mysterybox.pcf")
PrecacheParticleSystem("mysterybox_beam")
PrecacheParticleSystem("mysterybox_roll")

if SERVER then
	function EXT.GetBaseWeaponsTable()
		if table.IsEmpty(Settings.WeaponList) then
			-- Get installed weapons
			local t = {}
			for k,v in pairs(weapons.GetList()) do
				local wep = weapons.GetStored(v.ClassName)
				if wep and wep.Spawnable and not wep.nzu_PreventBox and not wep.NZPreventBox then
					local model = wep.WM or wep.WorldModel
					if model and model ~= "" then
						t[v.ClassName] = 1
					end
				end
			end
			return t
		end
		return Settings.WeaponList
	end

	util.AddNetworkString("nzu_MysteryBox_PrecacheWeapons")
	local function networkweaponsprecache(ply)
		net.Start("nzu_MysteryBox_PrecacheWeapons")
			local weps = EXT.GetBaseWeaponsTable()
			local num = table.Count(weps)
			net.WriteUInt(num, 16)
			for k,v in pairs(weps) do
				net.WriteString(k)
			end
		if ply then net.Send(ply) else net.Broadcast() end
	end
	hook.Add("PlayerInitialSpawn", "nzu_MysteryBox_PrecacheWeapons", networkweaponsprecache)

	local modelslist = {}
	function EXT.ReloadModelsList()
		modelslist = {}
		local weps = EXT.GetBaseWeaponsTable()
		for k,v in pairs(weps) do
			local wep = weapons.GetStored(k)
			if wep then
				local model = wep.WM or wep.WorldModel
				if model and model ~= "" then
					table.insert(modelslist, model)
					util.PrecacheModel(model)
				end
			end
		end

		-- Update all players' caches (this is expensive, but this function shouldn't happen unless the weapons are changed anyway)
		networkweaponsprecache()
	end
	function EXT.GetModelsList() return modelslist end
	--EXT.ReloadModelsList()

	function EXT.GetWeaponsTableFor(ply)
		local weps = EXT.GetBaseWeaponsTable()
		local possible = {}
		
		for k,v in pairs(weps) do
			if not IsValid(ply:GetWeapon(k)) then
				possible[k] = v
			end
		end

		hook.Run("nzu_MysteryBox_ModifyWeaponTableForPlayer", possible, ply) -- Allow a hook to modify the weapons table
		return possible
	end

	-- Weighted Random but ignoring all weapons that the player already has
	function EXT.DecideWeaponFor(ply)
		local possible = EXT.GetWeaponsTableFor(ply)
		local total = 0
		for k,v in pairs(possible) do
			total = total + v
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

	function EXT.ShouldGiveTeddy(box, ply)
		local b = hook.Run("nzu_MysteryBox_OverrideTeddy", box, ply)
		if b == nil then
			local r = math.random()
			local t = box:GetTimesUsed()
			local ch = t > 12 and 0.5 or t > 8 and 0.3 or 0.15 -- 50% over 12 uses, 30% 8-12 uses, 15% under 8 uses

			b = r < ch
		end
		
		-- If teddy was rolled, first check if a valid different box spawnpoint exists
		if b then
			local p = EXT.DecideSpawnpoint(box:GetSpawnpoint())
			if IsValid(p) then -- If it exists, then yes, we give teddy
				p.ReservedBox = box -- Reserve this point for this box to move to
				box.ReservedSpawnpoint = p
				return true
			end
		end
		return false
	end

	function EXT.SpawnMysteryBox(spawnpoint, ang)
		local point = spawnpoint or EXT.DecideSpawnpoint()
		if not IsValid(point) then return end

		local e = ents.Create("nzu_mysterybox")
		e:Appear(point, ang) -- Pass ang if you want to spawn it on a position (which also then needs an angle)
	end

	function EXT.MoveMysteryBox(box, newpoint)
		local point = newpoint

		-- If the box was set to move to some specific point, given through the Teddy roll logic
		if box.ReservedSpawnpoint then
			if not IsValid(point) then -- Only if "newpoint" wasn't forced though
				point = box.ReservedSpawnpoint -- Chosen point will be the reserved one
			end
			box.ReservedSpawnpoint.ReservedBox = nil -- Un-reserve
		end

		if not IsValid(point) then point = EXT.DecideSpawnpoint(box:GetSpawnpoint()) end -- If box doesn't have reserved, and no forced point, calculate a random one
		if IsValid(point) then EXT.SpawnMysteryBox(point) end -- If the final point is valid, spawn a new box there
		box:Remove() -- Remove the old box
	end

	function EXT.GetAllSpawnpoints()
		return ents.FindByClass("nzu_mysterybox_spawnpoint") -- This can be changed later in case of sub-classes? Depends on how box skins should work
	end

	function EXT.DecideSpawnpoint(blocked)
		local available = {}
		local blocks

		if type(blocked) == "table" then
			if blocked[1] then
				blocks = {}
				for k,v in pairs(blocked) do blocks[v] = true end
			else
				blocks = blocked
			end
		else
			blocks = {}
			if IsValid(blocked) then
				blocks[blocked] = true
			end
		end

		local points = EXT.GetAllSpawnpoints()
		for k,v in pairs(points) do
			if not blocks[v] and not IsValid(v:GetMysteryBox()) and not IsValid(v.ReservedBox) then -- All spawnpoints not blocked, not having a box currently, and not being reserved
				table.insert(available, v)
			end
		end

		local num = #available
		if num > 0 then
			return available[math.random(num)]
		end
	end

	-- Spawn the box when the map is reloaded! :D
	hook.Add("nzu_PostConfigMap", "nzu_MysteryBox_Initialize", function()
		local points = EXT.GetAllSpawnpoints()
		local possible = {}
		for k,v in pairs(points) do
			if v:GetIsPossibleSpawn() then table.insert(possible, v) end
		end

		if #possible < 1 then possible = points end -- None marked for initial spawn, just use all instead
		local point = possible[math.random(#possible)]
		if IsValid(point) then
			EXT.SpawnMysteryBox(point)
		end
	end)
end

-- Weapon precaching logic
if CLIENT then
	net.Receive("nzu_MysteryBox_PrecacheWeapons", function()
		local t = {}
		local num = net.ReadUInt(16)
		for i = 1,num do
			table.insert(t, net.ReadString())
		end

		local cmodel
		for k,v in pairs(t) do
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
	end)
end