
local SETTINGS = nzu.Extension().Settings
local ROUND = nzu.GetExtension("Core").Round

function ROUND:CalculateZombieHealth()
	return self.Round < 10 and
		SETTINGS.ZombieHealthBase + SETTINGS.ZombieHealthScaleLinear*self.Round
	or
		-- 950 for round 10, multiply 1.1 for each round after. Read settings instead of static numbers
		(SETTINGS.ZombieHealthBase + SETTINGS.ZombieHealthScaleLinear*10)*(math.pow(SETTINGS.ZombieHealthScalePower, self.Round-10))
end

function ROUND:CalculateZombieAmount()
	return math.Round(SETTINGS.ZombieNumberRoundScale * self.Round * (SETTINGS.ZombieNumberBase + SETTINGS.ZombieNumberPlayerScale * #self:GetPlayers()))
end