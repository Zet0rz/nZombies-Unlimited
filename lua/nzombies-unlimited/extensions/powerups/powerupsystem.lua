local EXT = nzu.Extension()
local S = EXT.Settings

-- Dropping powerups
function EXT.Powerup(id, pos, personal)
	local powerup = EXT.GetPowerup(id)
	if not powerup then return end

	local drop = ents.Create("nzu_powerup")
	drop:SetPowerup(id)
	drop:SetPersonal(powerup.PlayerBased and personal)
	drop:SetNegative(false)
	drop:SetPos(pos)
	drop:Spawn()
	return drop
end

function EXT.NegativePowerup(id, pos, personal)
	local powerup = EXT.GetPowerup(id)
	if not powerup or not powerup.Negative then return end

	local drop = ents.Create("nzu_powerup")
	drop:SetPowerup(id)
	drop:SetPersonal(powerup.PlayerBased and personal)
	drop:SetNegative(true)
	drop:SetPos(pos)
	drop:Spawn()
	return drop
end

-- Powerup Cycle (TODO)
local alreadydone = {}
local dropsthisround = 0
hook.Add("nzu_GameStarted", "nzu_Powerups_ResetCycle", function() alreadydone = {} dropsthisround = 0 end)
hook.Add("nzu_RoundChanged", "nzu_Powerups_ResetDropCount", function() dropsthisround = 0 end)

local chance = 50 -- 1 in 50
local maxdrops = 4
hook.Add("nzu_ZombieKilled", "nzu_Powerups_Drop", function(z)
	if dropsthisround < maxdrops then
		if math.random(50) == 1 then
			local area = navmesh.GetNearestNavArea(z:GetPos())
			if IsValid(area) then -- and area is not out of bounds: TODO
				local all = EXT.GetDroppablePowerups()
				local possible = {}
				for k,v in pairs(all) do
					if not alreadydone[v] then table.insert(possible, v) end
				end

				local num = #possible
				if num < 1 then
					alreadydone = {}
					possible = all
				end

				local up = possible[math.random(#possible)]
				local powerup = EXT.GetPowerup(up)
				if powerup then
					EXT.Powerup(up, z:GetPos(), powerup.DefaultPersonal)
					alreadydone[up] = true
					dropsthisround = dropsthisround + 1
				end
			end
		end
	end
end)