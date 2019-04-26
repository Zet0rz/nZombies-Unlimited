
-- Stamina system using non-networked, predicted Move hook conditioning
-- Both client and server check the sprint key and note the CurTime() down, using
-- that to determine the stamina at any point

-- It works by, at any given time a call to PLAYER:GetStamina() is run, it looks at the last "turning point" (i.e. where the sprint started or stopped)
-- It gets whatever the value was at that point, and subtracts or adds the value based on the time passed since then
-- This means there is NO networking! No constant changing values! It is just a calculation

local PLAYER = FindMetaTable("Player")

nzu.AddPlayerNetworkVar("Float", "StaminaTime") -- How long the player is able to sprint with his stamina
nzu.AddPlayerNetworkVar("Float", "StaminaRecoveryRate") -- How much stamina time the player recovers relative to the time spent recovering
local staminarecoerydelay = 0.75

function PLAYER:GetStamina()
	if not self.nzu_LastKnownStamina then self.nzu_LastKnownStamina = self:GetStaminaTime() end

	local CT = CurTime()
	if self.nzu_StaminaRecoveryStart then
		return math.Min(self.nzu_LastKnownStamina + math.Max(CurTime() - self.nzu_StaminaRecoveryStart, 0)*self:GetStaminaRecoveryRate(), self:GetStaminaTime())
	elseif self.nzu_StaminaDrainStart then
		return math.Max(self.nzu_LastKnownStamina - (CurTime() - self.nzu_StaminaDrainStart), 0)
	else
		return self.nzu_LastKnownStamina
	end
end

if SERVER then
	local defaultstamina = 5
	local defaultstaminarecovery = 1.25
	hook.Add("PlayerInitialSpawn", "nzu_Stamina_SpawnSet", function(ply)
		ply:SetStaminaTime(defaultstamina)
		ply:SetStaminaRecoveryRate(defaultstaminarecovery)
	end)
end

local function stopsprint(ply)
	ply.nzu_LastKnownStamina = ply:GetStamina()
	ply.nzu_StaminaDrainStart = nil
	ply.nzu_StaminaRecoveryStart = CurTime() + staminarecoerydelay
end

hook.Add("Move", "nzu_Stamina_PlayerMove", function(ply, mv)
	if mv:KeyDown(IN_SPEED) then

		-- If we're not already sprinting
		if not ply.nzu_StaminaDrainStart then
			local stamina = ply:GetStamina()
			if mv:KeyPressed(IN_SPEED) and stamina > 0 then
				ply.nzu_LastKnownStamina = stamina -- Save what value we start draining from
				ply.nzu_StaminaRecoveryStart = nil -- Stop recovering
				ply.nzu_StaminaDrainStart = CurTime() -- Save what time we started draining
			else
				-- We're sprinting, but we either have no stamina or didn't start it by initially pressing Shift
				-- Force the sprinting speed to be equal to walking speed
				mv:SetMaxSpeed(ply:GetWalkSpeed())
				mv:SetMaxClientSpeed(ply:GetWalkSpeed())
			end
		elseif ply:GetStamina() <= 0 then
			stopsprint(ply)
		end
	elseif mv:KeyReleased(IN_SPEED) and not ply.nzu_StaminaRecoveryStart then
		stopsprint(ply)
	end
end)