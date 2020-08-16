
local ROUND = nzu.Round or {}
nzu.Round = ROUND
local SETTINGS = nzu.GetExtension("core")

ROUND_INVALID = -1
ROUND_WAITING = 0
ROUND_PREPARING = 1
ROUND_ONGOING = 2
ROUND_GAMEOVER = 3

ROUND.Round = 0
ROUND.State = ROUND_WAITING

local roundbits = 16 -- 2^16 max round (65536)

--[[-------------------------------------------------------------------------
Shared getters
---------------------------------------------------------------------------]]
function ROUND:GetRound() return self.Round end
function ROUND:GetState() return self.State end

--[[-------------------------------------------------------------------------
Basic Round logic
---------------------------------------------------------------------------]]
if SERVER then
	if not ConVarExists("nzu_round_maxzombies") then CreateConVar("nzu_round_maxzombies", 24, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Sets the maximum number of Zombies that can be spawned at the same time in a round.") end
	if not ConVarExists("nzu_round_distributiondelay") then CreateConVar("nzu_round_distributiondelay", 10, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Sets the delay between each Zombie Distribution.") end
	local max = GetConVar("nzu_round_maxzombies")
	local delay = GetConVar("nzu_round_distributiondelay")

	util.AddNetworkString("nzu_round")
	local function donetwork()
		net.Start("nzu_round")
			net.WriteUInt(ROUND.Round, roundbits)
			net.WriteUInt(ROUND.State, 2)
		net.Broadcast()

		hook.Run("nzu_RoundStateChanged", ROUND.Round, ROUND.State)
	end

	hook.Add("PlayerInitialSpawn", "nzu_Round_State", function(ply)
		net.Start("nzu_round")
			net.WriteUInt(ROUND.Round, roundbits)
			net.WriteUInt(ROUND.State, 2)
		net.Send(ply)
	end)

	ROUND.Zombies = ROUND.Zombies or {} -- List of zombies that count for the round
	ROUND.NumberZombies = ROUND.NumberZombies or 0 -- Number of zombies that count for the round currently alive
	ROUND.ZombiesToSpawn = ROUND.ZombiesToSpawn or 0 -- Zombies still not spawned

	-- Localize
	local ZOMBIES = ROUND.Zombies

	function ROUND:GetRemainingZombies() return self.NumberZombies + self.ZombiesToSpawn end

	local weightedrandom = nzu.WeightedRandom
	local function dozombiespawn(z, spawner)
		z:ShouldGivePoints(true)

		local health = ROUND.ZombieHealth
		health = z.SelectHealth and z:SelectHealth(health) or health
		z:SetMaxHealth(health)
		z:SetHealth(health)

		--local speed = weightedrandom(ROUND.ZombieSpeeds)
		local speed = ROUND:CalculateZombieSpeed()
		speed = z.SelectMovementSpeed and z:SelectMovementSpeed(speed) or speed
		z:SetDesiredSpeed(speed)

		spawner:Spawn(z)
	end

	local function dozombieadd(z)
		ZOMBIES[z] = true -- Register as zombie

		ROUND.NumberZombies = ROUND.NumberZombies + 1
		ROUND.ZombiesToSpawn = ROUND.ZombiesToSpawn - 1
		z.nzu_RoundOwner = ROUND -- Set what round this zombie belongs to
	end

	local function dozombiedeath(z)
		if ZOMBIES[z] then
			ZOMBIES[z] = nil

			local round = z.nzu_RoundOwner
			if round then
				round.NumberZombies = round.NumberZombies - 1
				if z.nzu_RefundOnDeath then
					round.ZombiesToSpawn = round.ZombiesToSpawn + 1
				end
			end

			hook.Run("nzu_ZombieKilled", z)

			if round then
				if round:GetRemainingZombies() <= 0 then
					round:Progress()
				end
			end
		end
	end
	hook.Add("OnNPCKilled", "nzu_Round_ZombieDeath", dozombiedeath)
	hook.Add("EntityRemoved", "nzu_Round_ZombieDeath", dozombiedeath)
	--hook.Add("EntityRemoved", "nzu_Round_ZombieRemoved", dozombiedeath)

	function ROUND:GetZombies()
		return table.GetKeys(ZOMBIES)
	end

	-- Mark an enemy as a regular zombie. This is used in ROUND:GetZombies() (such as for nukes)
	function ROUND:RegisterZombie(z)
		ZOMBIES[z] = true
	end

	-- ADDS an entity as a zombie to the round. This both registers it AND makes it count for the round, adding +1 to the number of zombies to kill, and associating it with the round
	function ROUND:AddZombie(z)
		self:RegisterZombie(z)
		if not z.nzu_RoundOwner then
			z.nzu_RoundOwner = self
			self.NumberZombies = self.NumberZombies + 1
		end
	end

	--[[-------------------------------------------------------------------------
	Entity utilities
	---------------------------------------------------------------------------]]
	local ENTITY = FindMetaTable("Entity")

	-- This respawns the specific zombie by simply restoring health and position
	function ENTITY:Respawn()
		self:RefundZombie() -- ... eeeexcept it doesn't right now. TODO: How to make it just respawn? Spawners might be blocked
		self:TakeDamage(self:Health(), self, self)
	end

	-- "Refunds" a Zombie by dissociating it with its round controller, and adding +1 to zombies for it to spawn again
	-- This leaves the zombie still alive, but no longer counting for the round
	function ENTITY:RefundZombie()
		if self.nzu_RoundOwner then
			local round = self.nzu_RoundOwner

			round.ZombiesToSpawn = round.ZombiesToSpawn + 1
			round.NumberZombies = round.NumberZombies - 1

			self.nzu_RoundOwner = nil
		end
	end

	function ENTITY:IsZombie()
		return ZOMBIES[self]
	end

	function ENTITY:RegisterAsZombie()
		ZOMBIES[self] = true
	end


	--[[-------------------------------------------------------------------------
	The Spawn Handler
	It works by using the weights of Zombie Spawns to calculate a spawn rate
	Thereby making further away spawnpoints spawn less zombies by spawning them more rarely
	It will continuously do this until there are no more zombies to spawn

	It does currently not take Special Spawns and special zombie types into account
	(Special rounds come later)
	---------------------------------------------------------------------------]]
	local nextcheck = 0
	local nextdistribution = 0
	local distribution = {}
	local function thinkfunc()
		local ct = CurTime()
		if ct >= nextdistribution then
			distribution = {}
			for k,v in pairs(nzu.GetActiveSpawners("zombie")) do
				distribution[v] = 10 * (1-v:CalculateWeight()) + 0.5
			end
			nextdistribution = ct + delay:GetFloat()
		end

		if ct >= nextcheck then
			for k,v in pairs(distribution) do
				if ROUND.ZombiesToSpawn <= 0 or ROUND.NumberZombies >= max:GetInt() then break end

				if not k.NextSpawn or ct >= k.NextSpawn then
					if not k:IsFrozen() and not k:HasQueue() and k:HasSpace() then
						local z = ents.Create("nzu_zombie")
						dozombieadd(z)
						dozombiespawn(z, k)
					end
					k.NextSpawn = ct + v
				end
			end
			nextcheck = ct + 0.25 -- Just so we don't O(n) loop every single tick
		end
	end
	local function startongoing()
		ROUND.State = ROUND_ONGOING
		donetwork()

		hook.Add("Think", "nzu_Round_Spawning", thinkfunc)

		--[[if not timer.Start("nzu_Round_Spawning") then
			timer.Create("nzu_Round_Spawning", delay:GetFloat(), 0, function()
				if ROUND.ZombiesToSpawn > 0 and ROUND.CurrentZombies < max:GetInt() then
					ROUND:SpawnZombie()
				end
			end)
		end]]

		PrintMessage(HUD_PRINTTALK, "Round starting!")
		hook.Run("nzu_RoundStart", ROUND.Round)
	end

	function ROUND:Prepare(time)
		hook.Remove("Think", "nzu_Round_Spawning")

		self.State = ROUND_PREPARING
		donetwork()

		self.ZombiesToSpawn = self:CalculateZombieAmount()
		self.ZombieHealth = self:CalculateZombieHealth()
		--self.ZombieSpeeds = self:CalculateZombieSpeed()

		self.CurrentZombies = 0
		self.Zombies = {}

		if not timer.Start("nzu_Round_Prepare") then
			timer.Create("nzu_Round_Prepare", time or 10, 1, startongoing)
		end

		hook.Run("nzu_RoundPrepare", ROUND.Round, time)
	end

	function ROUND:SetRound(num, time)
		timer.Remove("nzu_Round_Prepare")
		--timer.Stop("nzu_Round_Spawning")
		self.Round = num
		PrintMessage(HUD_PRINTTALK, "Round is now: "..num)
		hook.Run("nzu_RoundChanged", num)

		self:SpawnPlayers()
		self:Prepare(time) -- This networks		
	end

	function ROUND:Progress()
		hook.Run("nzu_RoundEnd", self:GetRound())
		self:SetRound(self:GetRound() + 1) -- This networks
	end

	util.AddNetworkString("nzu_gamestartend")
	local initialpreparetime = 15
	function ROUND:Start(r, init)
		if self.State == ROUND_WAITING then
			local time = init or initialpreparetime
			self.State = ROUND_PREPARING
			self.Round = r or 1

			net.Start("nzu_gamestartend")
				net.WriteBool(true)
				net.WriteUInt(self.Round, roundbits)
				net.WriteFloat(time)
			net.Broadcast()

			hook.Remove("Think", "nzu_Round_Spawning")

			self:SpawnPlayers()

			self.ZombiesToSpawn = self:CalculateZombieAmount()
			self.ZombieHealth = self:CalculateZombieHealth()

			self.CurrentZombies = 0
			self.Zombies = {}

			if not timer.Start("nzu_Round_Prepare") then
				timer.Create("nzu_Round_Prepare", time, 1, startongoing)
			end

			hook.Run("nzu_RoundStateChanged", ROUND.Round, ROUND.State)
			hook.Run("nzu_RoundChanged", self.Round)
			hook.Run("nzu_GameStarted", time)
		end
	end

	local function doreset()
		for k,v in pairs(ROUND:GetPlayers()) do
			v:Unready()
		end

		local tbl = ROUND:GetZombies()
		ROUND.Zombies = {}
		ROUND.NumberZombies = 0
		ROUND.ZombiesToSpawn = 0

		for k,v in pairs(tbl) do
			v:Remove()
		end

		ROUND.State = ROUND_WAITING
		ROUND.Round = 0
		
		donetwork()
		nzu.ReloadConfigMap()
		hook.Run("nzu_GameReset")
	end

	local gameoversequencetime = 10
	local gameoverpresequencetime = 10
	local function dogameoversequence()

		net.Start("nzu_gamestartend")
			net.WriteBool(false)
			net.WriteBool(true)
			net.WriteFloat(gameoversequencetime)
		net.Broadcast()

		hook.Run("nzu_GameOverSequence", gameoversequencetime)

		if not timer.Start("nzu_Round_GameOver") then
			timer.Create("nzu_Round_GameOver", gameoversequencetime, 1, doreset)
		end
	end
	function ROUND:GameOver()
		timer.Remove("nzu_Round_Prepare")
		hook.Remove("Think", "nzu_Round_Spawning")
		self.State = ROUND_GAMEOVER

		PrintMessage(HUD_PRINTTALK, "GAME OVER! You survived "..self.Round.." rounds.")

		--donetwork()

		net.Start("nzu_gamestartend")
			net.WriteBool(false)
			net.WriteBool(false)
			net.WriteFloat(gameoverpresequencetime)
		net.Broadcast()

		if not timer.Start("nzu_Round_GameOver") then
			timer.Create("nzu_Round_GameOver", gameoverpresequencetime, 1, dogameoversequence)
		end

		hook.Run("nzu_GameOver", gameoverpresequencetime)
	end

	function ROUND:CalculateZombieHealth()
		-- 950 for round 10, multiply 1.1 for each round after
		local val = self.Round < 10 and 100 + 50*self.Round or 600*(math.pow(1.08, self.Round-10))
		--return val * 0.5 -- Scale down to gmod levels (for now). TODO: Balance
		return val
	end

	function ROUND:CalculateZombieAmount()
		return math.Round(0.15 * self.Round * (18 + 6 * self:GetPlayerCount()))
	end

	function ROUND:GetZombieHealth() return self.ZombieHealth end

	function ROUND:CalculateZombieSpeed(r)
		-- Generate a random number from a normal distribution
		-- Mean is based on the round itself
		-- Variance is 500, which gives nicely spread values averaging 20-50 away from the mean
		local r = r or self.Round
		return math.Clamp(math.Round(math.sqrt(-2 * 500 * math.log(math.random())) * math.cos(2*math.pi*math.random()) + r*15), 30,300)
	end
end

if CLIENT then
	net.Receive("nzu_round", function()
		ROUND.Round = net.ReadUInt(roundbits)
		ROUND.State = net.ReadUInt(2)

		hook.Run("nzu_RoundStateChanged", ROUND.Round, ROUND.State)
	end)

	net.Receive("nzu_gamestartend", function()
		if net.ReadBool() then
			ROUND.Round = net.ReadUInt(roundbits)
			ROUND.State = ROUND_PREPARING
			local time = net.ReadFloat()

			hook.Run("nzu_GameStarted", time)
			hook.Run("nzu_RoundStateChanged", ROUND.Round, ROUND.State)
		else
			ROUND.State = ROUND_GAMEOVER
			local h = net.ReadBool() and "nzu_GameOverSequence" or "nzu_GameOver"
			hook.Run(h, net.ReadFloat())
		end
	end)
end

--[[-------------------------------------------------------------------------
Player Downed registration
---------------------------------------------------------------------------]]
if SERVER then
	local function dogameovercheck()
		if ROUND.State == ROUND_WAITING or ROUND.State == ROUND_GAMEOVER then return end

		for k,v in pairs(ROUND:GetPlayers()) do
			if v:Alive() and not v:GetCountsDowned() then
				return
			end
		end
		ROUND:GameOver()
	end

	hook.Add("nzu_PlayerDowned", "nzu_Round_PlayerDowned", function(ply)
		timer.Simple(1, dogameovercheck) -- Delay a bit so other code can potentially set promised revives
	end)
	hook.Add("PostPlayerDeath", "nzu_Round_PlayerDeath", dogameovercheck)
end

--[[-------------------------------------------------------------------------
Round Sounds using ResourceSet setting in Core extension
---------------------------------------------------------------------------]]
if SERVER then
	hook.Add("nzu_RoundStart", "nzu_Round_Sounds", function(num)
		if num == 1 and file.Exists("sound/nzu/round/"..SETTINGS.RoundSounds.."/initial", "GAME") then return end

		local sounds = file.Find("sound/nzu/round/"..SETTINGS.RoundSounds.."/start/*", "GAME")
		local s = sounds[math.random(#sounds)]
		if s then nzu.PlayClientSound(s) end
	end)

	hook.Add("nzu_RoundEnd", "nzu_Round_Sounds", function(num)
		local sounds = file.Find("sound/nzu/round/"..SETTINGS.RoundSounds.."/end/*", "GAME")
		local s = sounds[math.random(#sounds)]
		if s then nzu.PlayClientSound(s) end
	end)

	hook.Add("nzu_GameStarted", "nzu_Round_Sounds", function()
		local sounds = file.Find("sound/nzu/round/"..SETTINGS.RoundSounds.."/initial/*", "GAME")
		local s = sounds[math.random(#sounds)]
		if s then nzu.PlayClientSound(s) end
	end)

	hook.Add("nzu_GameOver", "nzu_Round_Sounds", function()
		local sounds = file.Find("sound/nzu/round/"..SETTINGS.RoundSounds.."/gameover/*", "GAME")
		local s = sounds[math.random(#sounds)]
		if s then nzu.PlayClientSound(s) end
	end)
end



--[[-------------------------------------------------------------------------
Round Players: Team networking
---------------------------------------------------------------------------]]
ROUND.Team = TEAM_SURVIVORS
function ROUND:GetPlayers() return team.GetPlayers(self.Team) end
function ROUND:GetPlayerCount() return team.NumPlayers(self.Team) end
function ROUND:HasPlayer(ply) return ply:Team() == self.Team end




--[[-------------------------------------------------------------------------
Unspawn/Spawn system
Readying and dropping in/out
---------------------------------------------------------------------------]]
local PLAYER = FindMetaTable("Player")
function PLAYER:IsReady() return self.nzu_Ready end

--
local countdowntime = 5
--

if SERVER then
	util.AddNetworkString("nzu_ready") -- Client: Request readying || Server: Broadcast player ready states
	util.AddNetworkString("nzu_countdown") -- Server: Broadcast countdown start/stop

	local function docountdownstart()
		if not timer.Exists("nzu_RoundCountdown") then
			timer.Create("nzu_RoundCountdown", countdowntime, 1, function() nzu.Round:Start() end)
			hook.Run("nzu_RoundCountdown", countdowntime)

			net.Start("nzu_countdown")
				net.WriteBool(true)
			net.Broadcast()
		end
	end
	local function docountdowncancel()
		if timer.Exists("nzu_RoundCountdown") then
			timer.Destroy("nzu_RoundCountdown")
			hook.Run("nzu_RoundCountdownCancelled")

			net.Start("nzu_countdown")
				net.WriteBool(false)
			net.Broadcast()
		end
	end

	local function doreadycheck()
		-- We can change this later
		-- For now, just queue countdown and start game

		for k,v in pairs(player.GetAll()) do
			if v:IsReady() then -- Someone is ready
				docountdownstart()
				return
			end
		end
		
		docountdowncancel()
	end

	function PLAYER:ReadyUp()
		if not self.nzu_Ready then
			self.nzu_Ready = true

			net.Start("nzu_ready")
				net.WriteEntity(self)
				net.WriteBool(true)
			net.Broadcast()

			hook.Run("nzu_PlayerReady", self)

			if ROUND:GetState() == ROUND_WAITING then
				doreadycheck()
			elseif ROUND:GetState() == ROUND_PREPARING then
				ROUND:SpawnPlayer(self)
			end
		end
	end

	function PLAYER:Unready()
		if self.nzu_Ready then
			self.nzu_Ready = false

			net.Start("nzu_ready")
				net.WriteEntity(self)
				net.WriteBool(false)
			net.Broadcast()

			hook.Run("nzu_PlayerUnready", self)

			if ROUND:GetState() == ROUND_WAITING then
				doreadycheck()
			end
		end

		self:Unspawn()
	end

	net.Receive("nzu_ready", function(len, ply)
		if net.ReadBool() then ply:ReadyUp() else ply:Unready() end
	end)

	function ROUND:SpawnPlayer(v)
		v:Spawn()
		if SETTINGS.StartWeapon and SETTINGS.StartWeapon ~= "" then
			v:Give(SETTINGS.StartWeapon)
		end
		if SETTINGS.StartKnife and SETTINGS.StartKnife ~= "" then
			v:GiveWeaponInSlot(SETTINGS.StartKnife, "Knife")
		end
		if SETTINGS.StartGrenade and SETTINGS.StartGrenade ~= "" then
			v:GiveWeaponInSlot(SETTINGS.StartGrenade, "Grenade")
		end

		hook.Run("nzu_PlayerRespawned", ply)
	end

	function ROUND:SpawnPlayers()
		for k,v in pairs(player.GetAll()) do
			if v:IsReady() and not v:Alive() then
				self:SpawnPlayer(v)
			end
		end
	end

	hook.Add("PlayerSpawn", "nzu_Round_PlayerSpawn", function(ply)
		local spawnpoints = nzu.GetSpawners("player")
		if not spawnpoints then return end

		local num = #spawnpoints
		if num == 0 then return end

		local k = ply:EntIndex()

		local spawner = spawnpoints[(k-1)%num + 1]
		ply:SetPos(spawner:GetPos())
	end)

	hook.Add("PlayerInitialSpawn", "nzu_Round_ReadySync", function(ply)
		for k,v in pairs(player.GetAll()) do
			net.Start("nzu_ready")
				net.WriteEntity(v)
				net.WriteBool(v.nzu_Ready)
			net.Send(ply)
		end
	end)
else
	-- Receiving countdown
	net.Receive("nzu_countdown", function()
		if net.ReadBool() then
			nzu.Round.GameStart = CurTime() + countdowntime
			hook.Run("nzu_RoundCountdown", countdowntime)
		else
			nzu.Round.GameStart = nil
			hook.Run("nzu_RoundCountdownCancelled")
		end
	end)

	function nzu.Ready()
		net.Start("nzu_ready")
			net.WriteBool(true)
		net.SendToServer()
	end
	
	function nzu.Unready()
		net.Start("nzu_ready")
			net.WriteBool(false)
		net.SendToServer()
	end

	net.Receive("nzu_ready", function()
		local ply = net.ReadEntity()
		if net.ReadBool() then
			ply.nzu_Ready = true
			hook.Run("nzu_PlayerReady", ply)
		else
			ply.nzu_Ready = false
			hook.Run("nzu_PlayerUnready", ply)
		end
	end)
end