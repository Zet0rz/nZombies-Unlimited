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

function ENT:SelectMovementSpeed(speed)
	local n = #self.AnimTables
	local min = 1
	local max = 1
	for i = 1,n do
		local t = self.AnimTables[i]
		if t.Threshold <= speed then
			if not min then min = i end
		else
			max = i - 1
			break
		end
	end

	local t = self.AnimTables[math.random(min,max)]

	local spawns = t.Spawn
	self.SpawnSequence = spawns[math.random(#spawns)]

	local moves = t.Movement
	self.MovementSequence = moves[math.random(#moves)]

	self.AttackSequences = t.Attack
	self.VaultSequences = t.Vault

	return speed
end