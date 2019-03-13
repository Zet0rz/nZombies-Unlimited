
local ROUND = nzu.Round or {}
nzu.Round = ROUND
local SETTINGS = nzu.GetExtension("Core").Settings

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

	ROUND.Zombies = ROUND.Zombies or {} -- List
	ROUND.NumberZombies = 0 -- Count
	ROUND.ZombiesToSpawn = 0 -- Zombies still not spawned
	function ROUND:GetRemainingZombies() return self.NumberZombies + self.ZombiesToSpawn end

	local function dozombiespawn(z, spawner)
		--z:SetPos(Vector(0,0,0))
		--z:SetHealth(ROUND:GetZombieHealth())
		z:SetHealth(100)

		spawner:SpawnZombie(z, true)
		--z:Spawn()
	end
	function ROUND:SpawnZombie(spawner)
		local z = ents.Create("nzu_zombie")
		--z:SetModel("models/props_junk/wood_crate001a.mdl")
		z:ShouldGivePoints(true)

		self.NumberZombies = self.NumberZombies + 1
		self.ZombiesToSpawn = self.ZombiesToSpawn - 1
		self.Zombies[z] = true

		dozombiespawn(z, spawner)
		return z
	end
	local function dozombiedeath(z)
		if ROUND.Zombies[z] then
			if z.nzu_RefundOnDeath then
				ROUND.ZombiesToSpawn = ROUND.ZombiesToSpawn + 1
			end
			ROUND.Zombies[z] = nil
			ROUND.NumberZombies = ROUND.NumberZombies - 1

			if ROUND:GetRemainingZombies() <= 0 then
				ROUND:Progress()
			end
		end
	end
	hook.Add("EntityRemoved", "nzu_Round_ZombieDeath", dozombiedeath)
	--hook.Add("EntityRemoved", "nzu_Round_ZombieRemoved", dozombiedeath)

	local ENTITY = FindMetaTable("Entity")
	function ENTITY:Respawn() -- This respawns the specific zombie by simply restoring health and position
		if ROUND.Zombies[self] then
			dozombiespawn(self)
		end
	end
	
	function ROUND:RefundZombie(z) -- "Refunds" a Zombie by making it not count and adding a new zombie to spawn in its place
		if self.Zombies[z] then
			ROUND.Zombies[z] = nil
			self.ZombiesToSpawn = self.ZombiesToSpawn + 1
			self.NumberZombies = self.NumberZombies - 1
		end
	end

	function ROUND:GetZombies()
		return table.GetKeys(self.Zombies)
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
				if ROUND.ZombiesToSpawn <= 0 then break end

				if not k.NextSpawn or ct >= k.NextSpawn then
					if not k:IsFrozen() and not k:HasQueue() and k:HasSpace() then
						local z = ents.Create("nzu_zombie")
						z:ShouldGivePoints(true)

						ROUND.NumberZombies = ROUND.NumberZombies + 1
						ROUND.ZombiesToSpawn = ROUND.ZombiesToSpawn - 1
						ROUND.Zombies[z] = true

						k:Spawn(z) -- Spawn this zombie on the spawner
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
	end

	function ROUND:Prepare()
		self.State = ROUND_PREPARING
		donetwork()

		-- Change this later, the curve isn't quite accurate
		-- Based on the Z = 0.15*R x (24 + 6*[P-1])
		self.ZombiesToSpawn = self:CalculateZombieAmount()
		self.ZombieHealth = self:CalculateZombieHealth()

		self.CurrentZombies = 0
		self.Zombies = {}

		if not timer.Start("nzu_Round_Prepare") then
			timer.Create("nzu_Round_Prepare", 5, 1, startongoing)
		end
	end

	function ROUND:SetRound(num)
		--timer.Stop("nzu_Round_Spawning")
		hook.Remove("nzu_Round_Spawning")

		self.Round = num
		PrintMessage(HUD_PRINTTALK, "Round is now: "..num)
		self:SpawnPlayers()
		self:Prepare() -- This networks
	end

	function ROUND:Progress()
		self:SetRound(self:GetRound() + 1) -- This networks
	end

	function ROUND:Start()
		if self.State == ROUND_WAITING then self:SetRound(1) end
	end

	function ROUND:CalculateZombieHealth()
		-- 950 for round 10, multiply 1.1 for each round after
		return self.Round < 10 and 50 + 100*self.Round or 950*(math.pow(1.1, self.Round-10))
	end

	function ROUND:CalculateZombieAmount()
		return math.Round(0.15 * self.Round * (18 + 6 * #self:GetPlayers()))
	end

	function ROUND:GetZombieHealth() return self.ZombieHealth end
	function ROUND:GetZombieSpeed()
		return 100
	end
end

if CLIENT then
	net.Receive("nzu_round", function()
		ROUND.Round = net.ReadUInt(roundbits)
		ROUND.State = net.ReadUInt(2)

		hook.Run("nzu_RoundStateChanged", ROUND.Round, ROUND.State)
	end)
end



--[[-------------------------------------------------------------------------
Player Management
We use Teams to network the players belonging to the round system or not
---------------------------------------------------------------------------]]
-- The "Unspawned". A mysterious class of people that seemingly has no interaction with the world, yet await their place in it.
team.SetUp(TEAM_UNASSIGNED, "Unspawned", Color(100,100,100))

function ROUND:SetUpTeam(...)
	local i = 1
	team.SetUp(i, ...)
	self.Team = i
end
function ROUND:GetPlayers() return team.GetPlayers(self.Team) end
function ROUND:GetPlayerCount() return team.NumPlayers(self.Team) end

--
local countdowntime = 5
--

if SERVER then
	local function docountdownstart()
		if not timer.Exists("nzu_RoundCountdown") then
			timer.Create("nzu_RoundCountdown", countdowntime, 1, function() nzu.Round:Start() end)
			hook.Run("nzu_RoundCountdown", countdowntime)

			net.Start("nzu_ready")
				net.WriteBool(true)
			net.Broadcast()
		end
	end
	local function docountdowncancel()
		if timer.Exists("nzu_RoundCountdown") then
			timer.Destroy("nzu_RoundCountdown")
			hook.Run("nzu_RoundCountdownCancelled")

			net.Start("nzu_ready")
				net.WriteBool(false)
			net.Broadcast()
		end
	end

	local function doreadycheck()
		-- We can change this later
		-- For now, just queue countdown and start game

		for k,v in pairs(player.GetAll()) do
			if not v:IsUnspawned() then -- Someone is ready
				docountdownstart()
				return
			end
		end
		
		docountdowncancel()
	end

	function ROUND:AddPlayer(ply)
		ply:SetTeam(self.Team)

		local state = self:GetState()
		if state == ROUND_PREPARING then
			self:SpawnPlayer(ply)
		elseif state == ROUND_WAITING then
			doreadycheck()
		end
	end
	function ROUND:RemovePlayer(ply)
		nzu.Unspawn(ply)
		if nzu.Round:GetState() == ROUND_WAITING then doreadycheck() end
	end

	function ROUND:SpawnPlayer(ply)
		local spawnpoints = nzu.GetSpawners("player")
		local num = #spawnpoints
		local k = ply:EntIndex()

		local spawner = spawnpoints[(k-1)%num + 1]
		ply:SetPos(spawner:GetPos())
		ply:Spawn()
		ply:Give(SETTINGS.StartWeapon)
		ply:GiveAmmo(999, "Pistol")
		hook.Run("nzu_PlayerRespawned", ply)
	end

	function ROUND:SpawnPlayers()
		local spawnpoints = nzu.GetSpawners("player")
		local num = #spawnpoints
		for k,v in pairs(self:GetPlayers()) do
			if not v:Alive() then
				local spawner = spawnpoints[(k-1)%num + 1]
				v:SetPos(spawner:GetPos())
				v:Spawn()
				v:Give(SETTINGS.StartWeapon)
				v:GiveAmmo(999, "Pistol")
				hook.Run("nzu_PlayerRespawned", v)
			end
		end
	end
end
ROUND:SetUpTeam("Survivors", Color(100,255,150))


--[[-------------------------------------------------------------------------
Readying and dropping in/out
---------------------------------------------------------------------------]]
local PLAYER = FindMetaTable("Player")
function PLAYER:IsUnspawned()
	return self:Team() == TEAM_UNASSIGNED
end

if SERVER then
	util.AddNetworkString("nzu_ready") -- Client: Request readying || Server: Broadcast game countdown initialize
	net.Receive("nzu_ready", function(len, ply)
		local b = net.ReadBool()
		if b then
			if ply:IsUnspawned() then ROUND:AddPlayer(ply) end
		else
			if not ply:IsUnspawned() then ROUND:RemovePlayer(ply) end
		end
	end)
else
	-- Receiving countdown
	net.Receive("nzu_ready", function()
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
end


if SERVER then
	-- This is basically dropping out and being on the main menu
	-- You can spectate from here too (later)
	function nzu.Unspawn(ply)
		ply:SetTeam(TEAM_UNASSIGNED)
		ply:KillSilent()
	end
	
	function GM:PlayerInitialSpawn(ply)
		-- Is this timer really necessary? :(
		-- It doesn't seem to kill if not with the timer (probably cause it's before the spawn?)
		timer.Simple(0, function()
			if IsValid(ply) then
				nzu.Unspawn(ply)
				hook.Run("ShowHelp", ply) -- Open their F1 menu
			end
		end)
	end
	function GM:PlayerDeathThink() end
end

--[[-------------------------------------------------------------------------
Add HUD Component. Since this file only runs in nZombies, this component has been "ghost registered" in hudmanagement.lua
---------------------------------------------------------------------------]] 
if CLIENT then
	local font = "nzu_RoundNumber"
	surface.CreateFont(font, {
		font = "DK Umbilical Noose",
		size = 128,
		weight = 300,
		antialias = true,
	})

	local col = Color(255,0,0)
	local col_outline = Color(50,0,0)

	local lastdrawnround = 0
	local transitioncomplete
	local transitiontime = 3

	nzu.RegisterHUDComponentType("Round")
	nzu.RegisterHUDComponent("Round", "Unlimited", {
		Paint = function()
			local r = ROUND:GetRound()
			surface.SetFont(font)
			surface.SetTextPos(50, ScrH() - 150)

			if r ~= lastdrawnround then
				if not transitioncomplete then
					transitioncomplete = CurTime() + transitiontime
				end

				local pct = (transitioncomplete - CurTime())/transitiontime
				surface.SetTextColor(255,0,0,255*pct)
				surface.DrawText(lastdrawnround)

				render.ClearStencil()
				render.SetStencilEnable(true)
				render.ClearStencilBufferRectangle(50, ScrH() - 150, 200, ScrH() - 150*pct, 1)

				render.SetStencilReferenceValue(1)
				render.SetStencilCompareFunction(STENCIL_EQUAL)

				surface.SetTextColor(255,pct*200,pct*100,255)
				surface.SetTextPos(50, ScrH() - 150)
				surface.DrawText(r)

				render.SetStencilEnable(false)

				if pct <= 0 then
					lastdrawnround = r
					transitioncomplete = nil
				end
			else
				surface.SetTextColor(255,0,0)
				surface.DrawText(r)
			end
		end
	})
end