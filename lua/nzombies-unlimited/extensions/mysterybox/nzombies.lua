-- Include the Entities
include("mysterybox_entities.lua")

local EXT = nzu.Extension()
local Settings = EXT.Settings

if SERVER then
	function EXT.GetWeaponsTable()
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

	-- Weighted Random but ignoring all weapons that the player already has
	function EXT.DecideWeaponFor(ply)
		local hasweps = {}
		local weps = EXT.GetWeaponsTable()

		local total = 0
		for k,v in pairs(weps) do
			if IsValid(ply:GetWeapon(k)) then
				hasweps[k] = true
			else
				total = total + v
			end
		end

		local ran = math.random(total)
		local cur = 0
		for k,v in pairs(weps) do
			if not hasweps[k] then
				cur = cur + v
				if cur >= ran then
					return k
				end
			end
		end
	end

	function EXT.ShouldGiveTeddy(box, ply)
		return box:GetTimesUsed() > 1 -- DEBUG
	end

	function EXT.SpawnMysteryBox(spawnpoint)
		local point = spawnpoint or EXT.DecideSpawnpoint()
		if not IsValid(point) then return end

		local e = ents.Create("nzu_mysterybox")
		e:Appear(point)
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

		local points = ents.FindByClass("nzu_mysterybox_spawnpoint")
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
end