ROUND_INIT = 0
ROUND_PREPARE = 1
ROUND_ONGOING = 2
ROUND_GAMEOVER = 3
ROUND_FROZEN = 4

if SERVER then
	local controllers = {}
	hook.Add("InitPostEntity", "nZU_GetRoundControllers", function()
		
	end)
end