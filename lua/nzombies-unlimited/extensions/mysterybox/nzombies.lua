-- Include the Entities
include("mysterybox_entities.lua")

local EXT = nzu.Extension()
local Settings = EXT.Settings

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

	local modelslist = {}
	function EXT.ReloadModelsList()
		local weps = EXT.GetWeaponsTable()
		for k,v in pairs(weps) do
			local wep = weapons.GetStored(k)
			if wep then
				local model = wep.WM or wep.WorldModel
				if model and model ~= "" then table.insert(modelslist, model) end
			end
		end
	end
	function EXT.GetModelsList() return modelslist end
	EXT.ReloadModelsList()

	function EXT.GetWeaponsTableFor(ply)
		local weps = EXT.GetBaseWeaponsTable()
		local possible = {}
		
		for k,v in pairs(weps) do
			if not IsValid(ply:GetWeapon(k)) then
				possible[k] = v
				total = total + v
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
		if b ~= nil then return b end

		local r = math.random()
		local t = box:GetTimesUsed()
		local ch = t > 12 and 0.5 or t > 8 and 0.3 or 0.15 -- 50% over 12 uses, 30% 8-12 uses, 15% under 8 uses
		return r < ch
	end

	function EXT.SpawnMysteryBox(spawnpoint)
		local point = spawnpoint or EXT.DecideSpawnpoint()
		if not IsValid(point) then return end

		local e = ents.Create("nzu_mysterybox")
		e:Appear(point)
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
			if not blocks[v] and not IsValid(v:GetMysteryBox()) then
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