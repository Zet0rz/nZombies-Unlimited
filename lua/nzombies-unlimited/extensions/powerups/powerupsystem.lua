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