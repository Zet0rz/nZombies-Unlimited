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
ENT.MaxSpeed = 600
ENT.AnimTables = {
	-- 1: Arms Down
	[1] = {
		-- Slowest speed, arms down (ad)
		{Threshold = 0,
			Spawn = {"nz_spawn_climbout_fast"},
			Movement = {
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
			Attack = {
				{Sequence = "nz_attack_walk_ad_1", Impacts = {0.2}},
				{Sequence = "nz_attack_walk_ad_2", Impacts = {0.4, 0.8}},
				{Sequence = "nz_attack_walk_ad_3", Impacts = {0.3}},
				{Sequence = "nz_attack_walk_ad_4", Impacts = {0.1, 0.4}},
			},
			Vault = { "nz_barricade_walk_1", "nz_barricade_walk_2", "nz_barricade_walk_3", "nz_barricade_walk_4"},
		},

		-- Slower running, arms down (ad)
		{Threshold = 60,
			Spawn = {"nz_spawn_climbout_fast"},
			Movement = {
				"nz_run_ad7",
				"nz_run_ad8",
				"nz_run_ad11",
				"nz_run_ad20",
				"nz_run_ad21",
				"nz_run_ad24",
			},
			Attack = {
				{Sequence = "nz_attack_walk_ad_1", Impacts = {0.2}},
				{Sequence = "nz_attack_walk_ad_2", Impacts = {0.4, 0.8}},
				{Sequence = "nz_attack_walk_ad_3", Impacts = {0.3}},
				{Sequence = "nz_attack_walk_ad_4", Impacts = {0.1, 0.4}},
			},
			Vault = { "nz_barricade_walk_1", "nz_barricade_walk_2", "nz_barricade_walk_3", "nz_barricade_walk_4"},
		},

		-- Faster running, arms down (ad)
		{Threshold = 100,
			Spawn = {"nz_spawn_jump_run_1", "nz_spawn_jump_run_2", "nz_spawn_jump_run_3"},
			Movement = {
				"nz_run_ad1",
				"nz_run_ad2",
				"nz_run_ad4",
				"nz_run_ad12",
				"nz_run_ad14",
				"nz_run_ad23",
			},
			Attack = {
				{Sequence = "nz_attack_run_ad_1", Impacts = {0.6}},
				{Sequence = "nz_attack_run_ad_2", Impacts = {0.2}},
				{Sequence = "nz_attack_run_ad_3", Impacts = {0.6}},
				{Sequence = "nz_attack_run_ad_4", Impacts = {0.5}},
			},
			Vault = {"nz_barricade_run_1"}
		},

		-- Sprinting, arms down (ad)
		{Threshold = 140,
			Spawn = {"nz_spawn_jump_run_1", "nz_spawn_jump_run_2", "nz_spawn_jump_run_3"},
			Movement = {
				"nz_sprint_ad1",
				"nz_sprint_ad2",
				"nz_sprint_ad5",
				"nz_sprint_ad21",
				"nz_sprint_ad22",
				"nz_sprint_ad23",
				"nz_sprint_ad24",
			},
			Attack = {
				{Sequence = "nz_attack_run_ad_1", Impacts = {0.6}},
				{Sequence = "nz_attack_run_ad_2", Impacts = {0.2}},
				{Sequence = "nz_attack_run_ad_3", Impacts = {0.6}},
				{Sequence = "nz_attack_run_ad_4", Impacts = {0.5}},
			},
			Vault = {"nz_barricade_sprint_1", "nz_barricade_sprint_2", "nz_barricade_sprint_3", "nz_barricade_sprint_4"}
		},

		-- Super Sprint, arms down (ad)
		{Threshold = 180,
			Spawn = {"nz_spawn_jump_run_1", "nz_spawn_jump_run_2", "nz_spawn_jump_run_3"},
			Movement = {
				"nz_supersprint_ad1",
				"nz_supersprint_ad2"
			},
			Attack = {
				{Sequence = "nz_attack_run_ad_1", Impacts = {0.6}},
				{Sequence = "nz_attack_run_ad_2", Impacts = {0.2}},
				{Sequence = "nz_attack_run_ad_3", Impacts = {0.6}},
				{Sequence = "nz_attack_run_ad_4", Impacts = {0.5}},
			},
			Vault = {"nz_barricade_sprint_1", "nz_barricade_sprint_2", "nz_barricade_sprint_3", "nz_barricade_sprint_4"}
		},
	},

	-- 2: Arms Up
	[2] = {
		-- Also slowest speed, arms up (au)
		{Threshold = 0,
			Spawn = {"nz_spawn_climbout_fast"},
			Movement = {
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
			Attack = {
				{Sequence = "nz_attack_walk_au_1", Impacts = {0.2}},
				{Sequence = "nz_attack_walk_au_2", Impacts = {0.3, 0.6}},
				{Sequence = "nz_attack_walk_au_3", Impacts = {0.3}},
				{Sequence = "nz_attack_walk_au_4", Impacts = {0.4}},
			},
			Vault = { "nz_barricade_walk_1", "nz_barricade_walk_2", "nz_barricade_walk_3", "nz_barricade_walk_4"},
		},

		-- Slower running, arms up (au)
		{Threshold = 60,
			Spawn = {"nz_spawn_climbout_fast"},
			Movement = {
				"nz_run_au4",
				"nz_run_au5",
				"nz_run_au20",
				"nz_run_au22",
				"nz_run_au23",
				"nz_run_au24",
			},
			Attack = {
				{Sequence = "nz_attack_walk_au_1", Impacts = {0.2}},
				{Sequence = "nz_attack_walk_au_2", Impacts = {0.3, 0.6}},
				{Sequence = "nz_attack_walk_au_3", Impacts = {0.3}},
				{Sequence = "nz_attack_walk_au_4", Impacts = {0.4}},
			},
			Vault = { "nz_barricade_walk_1", "nz_barricade_walk_2", "nz_barricade_walk_3", "nz_barricade_walk_4"},
		},

		-- Faster running, arms up (au)
		{Threshold = 100,
			Spawn = {"nz_spawn_jump_run_1", "nz_spawn_jump_run_2", "nz_spawn_jump_run_3"},
			Movement = {
				"nz_run_au1",
				"nz_run_au2",
				"nz_run_ad9",
				"nz_run_ad11",
				"nz_run_ad13",
				"nz_run_ad21",
			},
			Attack = {
				{Sequence = "nz_attack_run_au_1", Impacts = {0.6}},
				{Sequence = "nz_attack_run_au_2", Impacts = {0.3}},
				{Sequence = "nz_attack_run_au_3", Impacts = {0.5}},
				{Sequence = "nz_attack_run_au_4", Impacts = {0.5}},
			},
			Vault = {"nz_barricade_run_1"}
		},

		-- Sprinting, arms up (au)
		{Threshold = 140,
			Spawn = {"nz_spawn_jump_run_1", "nz_spawn_jump_run_2", "nz_spawn_jump_run_3"},
			Movement = {
				"nz_sprint_au1",
				"nz_sprint_au2",
				"nz_sprint_au20",
				"nz_sprint_au21",
				"nz_sprint_au22",
				"nz_sprint_au25",
			},
			Attack = {
				{Sequence = "nz_attack_run_au_1", Impacts = {0.6}},
				{Sequence = "nz_attack_run_au_2", Impacts = {0.3}},
				{Sequence = "nz_attack_run_au_3", Impacts = {0.5}},
				{Sequence = "nz_attack_run_au_4", Impacts = {0.5}},
			},
			Vault = {"nz_barricade_sprint_1", "nz_barricade_sprint_2", "nz_barricade_sprint_3", "nz_barricade_sprint_4"}
		},

		-- Super Sprint, arms up (au)
		{Threshold = 180,
			Spawn = {"nz_spawn_jump_run_1", "nz_spawn_jump_run_2", "nz_spawn_jump_run_3"},
			Movement = {
				"nz_supersprint_au1",
				"nz_supersprint_au2"
			},
			Attack = {
				{Sequence = "nz_attack_run_au_1", Impacts = {0.6}},
				{Sequence = "nz_attack_run_au_2", Impacts = {0.3}},
				{Sequence = "nz_attack_run_au_3", Impacts = {0.5}},
				{Sequence = "nz_attack_run_au_4", Impacts = {0.5}},
			},
			Vault = {"nz_barricade_sprint_1", "nz_barricade_sprint_2", "nz_barricade_sprint_3", "nz_barricade_sprint_4"}
		},
	}
}

function ENT:SelectMovementSpeed(speed)
	if not self.AnimTableIndex then self.AnimTableIndex = math.random(#self.AnimTables) end
	local tbl = self.AnimTables[self.AnimTableIndex]

	local n = #tbl
	local t
	for i = 1,n do
		if tbl[i].Threshold <= speed then
			t = tbl[i]
			break
		end
	end

	local spawns = t.Spawn
	self.SpawnSequence = spawns[math.random(#spawns)]

	local moves = t.Movement
	self.MovementSequence = moves[math.random(#moves)]

	self.AttackSequences = t.Attack
	self.VaultSequences = t.Vault

	return speed
end

function ENT:SelectVaultSequence(pos)
	return self.VaultSequences[math.random(#self.VaultSequences)], 50
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
	local result = self:MoveToPos(pos, {lookahead = 20, tolerance = 10, maxage = 3, draw = true})
	if result == "ok" and not self:ShouldEventTerminate() then
		-- We're in position
		self:SetPos(pos) -- Just because the animations are very precise here
		self:FaceTowards(barricade:LocalToWorld(Vector(0,barricade:WorldToLocal(pos).y,0))) -- Just face fowards, not towards the center of the barricade

		local planktotear = barricade:StartTear(self)
		while IsValid(planktotear) do
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

			if self:ShouldEventTerminate() then break end
			planktotear = barricade:StartTear(self)
		end
	else
		self:Timeout(2)
	end
	if barricade.m_tReservedSpots[pos] == self then barricade.m_tReservedSpots[pos] = nil end
end

-- DEBUG
function ENT:Event_Spawn() end