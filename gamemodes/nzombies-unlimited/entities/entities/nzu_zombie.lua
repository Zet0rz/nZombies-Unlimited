AddCSLuaFile()

ENT.Base = "nzu_zombie_base"
ENT.Type = "nextbot"
ENT.Category = "nZombies Unlimited"
ENT.Author = "Zet0r"
ENT.Spawnable = true

--[[-------------------------------------------------------------------------
This is an extension of "nzu_zombie_base" which adds:
- Movement speed-based animation decision
- Barricade tearing animation loops
- 

This is also the spawnable entity of the main Zombie type
---------------------------------------------------------------------------]]
if CLIENT then return end -- Client doesn't really need anything beyond the basics

ENT.DeathRagdollForce = 1000
ENT.DeathAnimations = {
	"nz_death_1",
	"nz_death_2",
	"nz_death_3",
	"nz_death_f_1",
	"nz_death_f_2",
	"nz_death_f_3",
	"nz_death_f_4",
	"nz_death_f_5",
	"nz_death_f_6",
	"nz_death_f_7",
	"nz_death_f_8",
	"nz_death_f_9",
	"nz_death_f_10",
	"nz_death_f_11",
	"nz_death_f_12",
	"nz_death_f_13",
}

-- Localizing tables so that we save a bit of memory instead of having multiple identical tables
local spawnslow = {"nz_spawn_climbout_fast"}
local spawnfast = {"nz_spawn_jump_run_1", "nz_spawn_jump_run_2", "nz_spawn_jump_run_3"}
local attack_walk_ad = {
	{Sequence = "nz_attack_walk_ad_1", Impacts = {0.2}},
	{Sequence = "nz_attack_walk_ad_2", Impacts = {0.4, 0.8}},
	{Sequence = "nz_attack_walk_ad_3", Impacts = {0.3}},
	{Sequence = "nz_attack_walk_ad_4", Impacts = {0.1, 0.4}},
}
local vault_walk = {
	{Sequence = "nz_barricade_walk_1", Speed = 50},
	{Sequence = "nz_barricade_walk_2", Speed = 50},
	{Sequence = "nz_barricade_walk_3", Speed = 50},
	{Sequence = "nz_barricade_walk_4", Speed = 50},
}
local attack_run_ad = {
	{Sequence = "nz_attack_run_ad_1", Impacts = {0.6}},
	{Sequence = "nz_attack_run_ad_2", Impacts = {0.2}},
	{Sequence = "nz_attack_run_ad_3", Impacts = {0.6}},
	{Sequence = "nz_attack_run_ad_4", Impacts = {0.5}},
}
local vault_run = {
	{Sequence = "nz_barricade_run_1", Speed = 70}
}
local vault_sprint = {
	{Sequence = "nz_barricade_sprint_1", Speed = 70},
	{Sequence = "nz_barricade_sprint_2", Speed = 50},
	{Sequence = "nz_barricade_sprint_3", Speed = 70},
	{Sequence = "nz_barricade_sprint_4", Speed = 70},
}
local attack_walk_au = {
	{Sequence = "nz_attack_walk_au_1", Impacts = {0.2}},
	{Sequence = "nz_attack_walk_au_2", Impacts = {0.3, 0.6}},
	{Sequence = "nz_attack_walk_au_3", Impacts = {0.3}},
	{Sequence = "nz_attack_walk_au_4", Impacts = {0.4}},
}
local attack_run_au = {
	{Sequence = "nz_attack_run_au_1", Impacts = {0.6}},
	{Sequence = "nz_attack_run_au_2", Impacts = {0.3}},
	{Sequence = "nz_attack_run_au_3", Impacts = {0.5}},
	{Sequence = "nz_attack_run_au_4", Impacts = {0.5}},
}

local walksounds = {
	Sound("nzu/zombie/amb/amb_00.wav"),
	Sound("nzu/zombie/amb/amb_01.wav"),
	Sound("nzu/zombie/amb/amb_02.wav"),
	Sound("nzu/zombie/amb/amb_03.wav"),
	Sound("nzu/zombie/amb/amb_04.wav"),
	Sound("nzu/zombie/amb/amb_05.wav"),
}
local runsounds = {
	Sound("nzu/zombie/sprint/sprint_00.wav"),
	Sound("nzu/zombie/sprint/sprint_01.wav"),
	Sound("nzu/zombie/sprint/sprint_02.wav"),
	Sound("nzu/zombie/sprint/sprint_03.wav"),
	Sound("nzu/zombie/sprint/sprint_04.wav"),
	Sound("nzu/zombie/sprint/sprint_05.wav"),
	Sound("nzu/zombie/sprint/sprint_06.wav"),
	Sound("nzu/zombie/sprint/sprint_07.wav"),
	Sound("nzu/zombie/sprint/sprint_08.wav"),
}

ENT.MaxSpeed = 600
ENT.AnimTables = {
	-- 1: Arms Down
	[1] = {
		-- Slowest speed, arms down (ad)
		{Threshold = 0,
			SpawnSequence = spawnslow,
			MovementSequence = {
				"nz_walk_ad1",
				"nz_walk_ad2",
				"nz_walk_ad3",
				"nz_walk_ad4",
				"nz_walk_ad5",
				"nz_walk_ad6",
				"nz_walk_ad7",
				"nz_walk_ad19",
				"nz_walk_ad20",
				"nz_walk_ad21",
				"nz_walk_ad22",
				"nz_walk_ad23",
				"nz_walk_ad24",
				"nz_walk_ad25",
			},
			AttackSequences = attack_walk_ad,
			VaultSequence = vault_walk,
			PassiveSounds = walksounds,
		},

		-- Slower running, arms down (ad)
		{Threshold = 100,
			SpawnSequence = spawnslow,
			MovementSequence = {
				"nz_run_ad7",
				"nz_run_ad8",
				"nz_run_ad11",
				"nz_run_ad20",
				"nz_run_ad21",
				"nz_run_ad24",
			},
			AttackSequences = attack_walk_ad,
			VaultSequence = vault_walk,
			PassiveSounds = walksounds,
		},

		-- Faster running, arms down (ad)
		{Threshold = 160,
			SpawnSequence = spawnslow,
			MovementSequence = {
				"nz_run_ad1",
				"nz_run_ad2",
				"nz_run_ad4",
				"nz_run_ad12",
				"nz_run_ad14",
				"nz_run_ad23",
			},
			AttackSequences = attack_run_ad,
			VaultSequence = vault_run,
			PassiveSounds = runsounds,
		},

		-- Sprinting, arms down (ad)
		{Threshold = 200,
			SpawnSequence = spawnfast,
			MovementSequence = {
				"nz_sprint_ad1",
				"nz_sprint_ad2",
				"nz_sprint_ad5",
				"nz_sprint_ad21",
				"nz_sprint_ad22",
				"nz_sprint_ad23",
				"nz_sprint_ad24",
			},
			AttackSequences = attack_run_ad,
			VaultSequence = vault_sprint,
			PassiveSounds = runsounds,
		},

		-- Super Sprint, arms down (ad)
		{Threshold = 250,
			SpawnSequence = spawnfast,
			MovementSequence = {
				"nz_supersprint_ad1",
				"nz_supersprint_ad2"
			},
			AttackSequences = attack_run_ad,
			VaultSequence = vault_sprint,
			PassiveSounds = runsounds,
		},
	},

	-- 2: Arms Up
	[2] = {
		-- Also slowest speed, arms up (au)
		{Threshold = 0,
			SpawnSequence = spawnslow,
			MovementSequence = {
				"nz_walk_au1",
				"nz_walk_au2",
				"nz_walk_au3",
				"nz_walk_au4",
				"nz_walk_au5",
				"nz_walk_au6",
				"nz_walk_au7",
				"nz_walk_au8",
				"nz_walk_au10",
				"nz_walk_au11",
				"nz_walk_au12",
				"nz_walk_au13",
				"nz_walk_au15",
				"nz_walk_au20",
				"nz_walk_au21",
				"nz_walk_au23",
			},
			AttackSequences = attack_walk_au,
			VaultSequence = vault_walk,
			PassiveSounds = walksounds,
		},

		-- Slower running, arms up (au)
		{Threshold = 100,
			SpawnSequence = spawnfast,
			MovementSequence = {
				"nz_run_au4",
				"nz_run_au5",
				"nz_run_au20",
				"nz_run_au22",
				"nz_run_au23",
				"nz_run_au24",
			},
			AttackSequences = attack_walk_au,
			VaultSequence = vault_walk,
			PassiveSounds = walksounds,
		},

		-- Faster running, arms up (au)
		{Threshold = 160,
			SpawnSequence = spawnfast,
			MovementSequence = {
				"nz_run_au1",
				"nz_run_au2",
				"nz_run_au9", -- This one is T-Pose
				"nz_run_au11",
				"nz_run_au13", -- This one too
				"nz_run_au21",
			},
			AttackSequences = attack_run_au,
			VaultSequence = vault_run,
			PassiveSounds = runsounds,
		},

		-- Sprinting, arms up (au)
		{Threshold = 200,
			SpawnSequence = spawnfast,
			MovementSequence = {
				"nz_sprint_au1",
				"nz_sprint_au2",
				"nz_sprint_au20",
				"nz_sprint_au21",
				"nz_sprint_au22",
				"nz_sprint_au25",
			},
			AttackSequences = attack_run_au,
			VaultSequence = vault_sprint,
			PassiveSounds = runsounds,
		},

		-- Super Sprint, arms up (au)
		{Threshold = 250,
			SpawnSequence = spawnfast,
			MovementSequence = {
				"nz_supersprint_au1",
				"nz_supersprint_au2"
			},
			AttackSequences = attack_run_au,
			VaultSequence = vault_sprint,
			PassiveSounds = runsounds,
		},
	}
}

-- Pick a random subtable of AnimTables to poll
-- Poll all of them until we find one that we cross the threshold for
-- Apply all fields of that onto ourselves
function ENT:SpeedChanged(speed)
	local tbl = self.AnimTables[2]--math.random(#self.AnimTables)]

	local n = #tbl
	local t
	for i = 1,n do
		if tbl[i].Threshold > speed then
			break
		else
			t = tbl[i]
		end
	end

	-- Movement sequence we pick a single random of! This makes the zombie always use the same one for its lifespan (until speed change)
	if t.MovementSequence then
		self.MovementSequence = t.MovementSequence[math.random(#t.MovementSequence)]
		self:ResetMovementSequence()
	end

	-- Apply all the remaining data from the AnimTable directly
	for k,v in pairs(t) do
		if k ~= "MovementSequence" then self[k] = v end
	end
end

-- Now we have data applied to our Zombie. We still need to modify the parts that don't use tables to that they can

-- Vault: Select from table
function ENT:SelectVaultSequence(pos)
	local seq = self.VaultSequence[math.random(#self.VaultSequence)]
	return seq.Sequence, seq.Speed
end

-- Spawn: Select from table
function ENT:SelectSpawnSequence()
	local s
	if self.SpawnSounds then s = self.SpawnSounds[math.random(#self.SpawnSounds)] end
	return self.SpawnSequence[math.random(#self.SpawnSequence)], s
end


--[[-------------------------------------------------------------------------
Sounds
We an additional sound type: When we're behind a player, we play a different sound
---------------------------------------------------------------------------]]
ENT.BehindSoundDistance = 200 -- Set to 0 to disable
ENT.BehindSounds = {
	Sound("nzu/zombie/behind/behind_00.wav"),
	Sound("nzu/zombie/behind/behind_01.wav"),
	Sound("nzu/zombie/behind/behind_02.wav"),
	Sound("nzu/zombie/behind/behind_03.wav"),
	Sound("nzu/zombie/behind/behind_04.wav"),
}
function ENT:Sound()
	if self.BehindSoundDistance > 0 -- We have enabled behind sounds
		and IsValid(self.Target)
		and self.Target:IsPlayer() -- We have a target and it's a player within distance
		and self:GetRangeTo(self.Target) <= self.BehindSoundDistance
		and (self.Target:GetPos() - self:GetPos()):GetNormalized():Dot(self.Target:GetAimVector()) >= 0 then -- If the direction towards the player is same 180 degree as the player's aim (away from the zombie)
			self:PlaySound(self.BehindSounds[math.random(#self.BehindSounds)], SNDLVL_140) -- Play the behind sound, and a bit louder!
	else
		self:PlaySound(self.PassiveSounds[math.random(#self.PassiveSounds)])
	end
end

--[[-------------------------------------------------------------------------
Custom barricade tear animations
---------------------------------------------------------------------------]]

-- Found by testing where the planks fit pose parameter -1 and +1
local blend_bot_dist = 37
local blend_top_dist = 85 - blend_bot_dist

local blend_ang_negative = 45
local blend_ang_positive = 135 - blend_ang_negative

local pulldelay = 0.1 -- Looks a bit better for pulling

function ENT:CalculateBarricadeAnims(pos, ang)
	-- Calculate blends based on angles
	local diff = self:WorldToLocal(pos)
	local pose_p = ((diff.z - blend_bot_dist)/blend_top_dist)*2 - 1
	local diff2 = self:WorldToLocalAngles(ang)
	local pose_r = ((diff2.r - blend_ang_negative)/blend_ang_positive)*2 - 1

	local barricade = self:GetInteractingEntity()
	if barricade:WorldToLocal(self:GetPos()).x > 0 then pose_r = pose_r*-1 end -- TODO: Can we use diff2 for this instead?

	-- Set the blends
	self:SetPoseParameter("barricade_p", pose_p)
	self:SetPoseParameter("barricade_r", pose_r)

	-- Return the animations to play
	if diff.y < -30 then
		return "nz_boardtear_blend_horizontal_l_grab", "nz_boardtear_blend_horizontal_l_hold", "nz_boardtear_blend_horizontal_l_pull"
	end
	if diff.y > 30 then
		return "nz_boardtear_blend_horizontal_r_grab", "nz_boardtear_blend_horizontal_r_hold", "nz_boardtear_blend_horizontal_r_pull"
	end
	return "nz_boardtear_blend_horizontal_m_grab", "nz_boardtear_blend_horizontal_m_hold", "nz_boardtear_blend_horizontal_m_pull"
end

function ENT:Event_BarricadeTear(barricade)
	if not barricade:HasAvailablePlanks() then
		self:Timeout(2) -- Do nothing for 2 seconds
	return end

	local pos = barricade:ReserveAvailableTearPosition(self)
	if not pos then
		self:Timeout(2) -- Do nothing for 2 seconds
	return end

	-- We got a barricade position, move towards it
	self:SolidMaskDuringEvent(MASK_NPCSOLID_BRUSHONLY)
	local result = self:MoveToPos(pos, {lookahead = 10, tolerance = 5, maxage = 3}) -- DEBUG (draw = true)
	if result == "ok" and not self:ShouldEventTerminate() then
		-- We're in position
		self:SetPos(pos) -- Just because the animations are very precise here
		self:FaceTowards(barricade:LocalToWorld(Vector(0,barricade:WorldToLocal(pos).y,0))) -- Just face fowards, not towards the center of the barricade

		
		while not self:ShouldEventTerminate() and not barricade:GetIsClear() do
			local planktotear = barricade:StartTear(self)
			if IsValid(planktotear) then
				local pos = planktotear:GetGrabPos()
				local ang = planktotear:GetGrabAngles()

				local a,b,c = self:CalculateBarricadeAnims(pos, ang)

				-- Get times and sequences
				local grab,gdur = self:LookupSequence(a)
				local hold,hdur = self:LookupSequence(b)
				local pull,pdur = self:LookupSequence(c)

				-- Perform grab and wait its duration
				self:SetCycle(0)
				self:ResetSequence(grab)
				coroutine.wait(gdur)

				-- Determine hold duration and play that loop for that long
				local time = planktotear:GetPlankTearTime() - gdur - pdur
				if time > 0 then
					self:ResetSequence(hold)
					coroutine.wait(time)
				end

				-- Pull the plank!
				self:ResetSequence(pull)
				self:SetCycle(0)
				coroutine.wait(pulldelay)

				barricade:TearPlank(self, planktotear)
				local phys = planktotear:GetPhysicsObject()
				if IsValid(phys) then
					local vec = self:GetPos() - planktotear:GetPos()
					vec.z = 0
					phys:SetVelocity(vec*3)
				end
				coroutine.wait(pdur - pulldelay)
			else
				self:Timeout(2)
			end
		end

		if not self:ShouldEventTerminate() then
			if barricade.m_tReservedSpots[pos] == self then barricade.m_tReservedSpots[pos] = NULL end
			self:SolidMaskDuringEvent() -- Remove the mask
			self:TriggerEvent("BarricadeVault", barricade, barricade.VaultHandler)
			return
		end
	else
		self:Timeout(2)
	end
	if barricade.m_tReservedSpots[pos] == self then barricade.m_tReservedSpots[pos] = NULL end
end