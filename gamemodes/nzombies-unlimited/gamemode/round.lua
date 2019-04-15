
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
		z:ShouldGivePoints(true)

		local health = ROUND:CalculateZombieHealth()
		health = z.SelectHealth and z:SelectHealth(health) or health
		z:SetMaxHealth(health)
		z:SetHealth(health)

		local speed = ROUND:CalculateZombieSpeed()
		speed = z.SelectMovementSpeed and z:SelectMovementSpeed(speed) or speed
		z:SetDesiredSpeed(speed)

		spawner:Spawn(z)
	end

	local function dozombieadd(z)
		ROUND.NumberZombies = ROUND.NumberZombies + 1
		ROUND.ZombiesToSpawn = ROUND.ZombiesToSpawn - 1
		ROUND.Zombies[z] = true
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
			ROUND:RefundZombie(self) -- ... eeeexcept it doesn't right now. TODO: How to make it just respawn? Spawners might be blocked
			self:TakeDamage(self:Health(), self, self)
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

		self.CurrentZombies = 0
		self.Zombies = {}

		if not timer.Start("nzu_Round_Prepare") then
			timer.Create("nzu_Round_Prepare", time or 10, 1, startongoing)
		end
	end

	function ROUND:SetRound(num, time)
		timer.Remove("nzu_Round_Prepare")
		--timer.Stop("nzu_Round_Spawning")
		self.Round = num
		PrintMessage(HUD_PRINTTALK, "Round is now: "..num)
		self:SpawnPlayers()
		self:Prepare(time) -- This networks

		hook.Run("nzu_RoundChanged", num)
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

		-- TODO: Reload config? Respawn props and such. A map reload is not needed to replay the same config
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
		local val = self.Round < 10 and 50 + 100*self.Round or 950*(math.pow(1.1, self.Round-10))
		return val * 0.5 -- Scale down to gmod levels (for now). TODO: Balance
	end

	function ROUND:CalculateZombieAmount()
		return math.Round(0.15 * self.Round * (18 + 6 * self:GetPlayerCount()))
	end

	function ROUND:GetZombieHealth() return self.ZombieHealth end

	function ROUND:CalculateZombieSpeed()
		return 100
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
		print("Player downed", ply)
		timer.Simple(1, dogameovercheck) -- Delay a bit so other code can potentially set promised revives
	end)
	hook.Add("PostPlayerDeath", "nzu_Round_PlayerDeath", dogameovercheck)
end

--[[-------------------------------------------------------------------------
Round Sounds using ResourceSet setting in Core extension
---------------------------------------------------------------------------]]
if SERVER then
	-- Sounds!
	local statemap = {
		[ROUND_ONGOING] = "Start",
		[ROUND_PREPARING] = "End",
		[ROUND_GAMEOVER] = "GameOver",
	}
	local sounds = nzu.GetResources("RoundSounds")
	hook.Add("nzu_RoundStart", "nzu_Round_Sounds", function(num)
		if num == 1 and sounds.Initial then return end
		local s = sounds.Start and sounds.Start[math.random(#sounds.Start)]
		if s then nzu.PlayClientSound(s) end
	end)

	hook.Add("nzu_RoundEnd", "nzu_Round_Sounds", function(num)
		local s = sounds.End and sounds.End[math.random(#sounds.End)]
		if s then nzu.PlayClientSound(s) end
	end)

	hook.Add("nzu_GameStarted", "nzu_Round_Sounds", function()
		local s = sounds.Initial and sounds.Initial[math.random(#sounds.Initial)]
		if s then nzu.PlayClientSound(s) end
	end)

	hook.Add("nzu_GameOver", "nzu_Round_Sounds", function()
		local s = sounds.GameOver and sounds.GameOver[math.random(#sounds.GameOver)]
		if s then nzu.PlayClientSound(s) end
	end)

	nzu.AddResourceSet("RoundSounds", "Classic", {
		Start = {
			"nzu/round/round_start.mp3"
		},
		End = {
			"nzu/round/round_end.mp3"
		},
		GameOver = {
			"nzu/round/game_over_5.mp3"
		},
	})

	nzu.AddResourceSet("RoundSounds", "The Giant", {
		Start = {
			"nzu/round/thegiant/round_start_1.wav",
			"nzu/round/thegiant/round_start_2.wav",
			"nzu/round/thegiant/round_start_3.wav",
			"nzu/round/thegiant/round_start_4.wav"
		},
		End = {
			"nzu/round/thegiant/round_end.wav"
		},
		GameOver = {
			"nzu/round/game_over_derriese.mp3"
		},
		-- DEBUG
		Initial = {
			"nzu/round/round_-1_prepare.mp3",
		}
	})
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
		if not v:CanAfford(SETTINGS.StartPoints) then
			v:SetPoints(SETTINGS.StartPoints)
		end

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
		if not ply:IsUnspawned() then
			local spawnpoints = nzu.GetSpawners("player")
			if not spawnpoints then return end

			local num = #spawnpoints
			if num == 0 then return end

			local k = ply:EntIndex()

			local spawner = spawnpoints[(k-1)%num + 1]
			ply:SetPos(spawner:GetPos())
		end
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


if SERVER then
	-- This is basically dropping out and being on the main menu
	-- You can spectate from here too (later)
	
	function GM:PlayerInitialSpawn(ply)
		-- Is this timer really necessary? :(
		-- It doesn't seem to kill if not with the timer (probably cause it's before the spawn?)
		timer.Simple(0, function()
			if IsValid(ply) then
				--nzu.Unspawn(ply)
				--hook.Run("ShowHelp", ply) -- Open their F1 menu
				-- DEBUG
				timer.Simple(1, function()
					ply:Give("weapon_pistol")
					ply:Give("weapon_ar2")
				end)
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
		weight = 500,
		antialias = true,
	})

	local col = Color(255,0,0)
	local col_outline = Color(50,0,0)

	local lastdrawnround = 0
	local transitioncomplete
	local transitiontime = 3

	local tallysize = 150
	local tallymats = {
		Material("nzombies-unlimited/hud/tally_1.png", "unlitgeneric smooth"),
		Material("nzombies-unlimited/hud/tally_2.png", "unlitgeneric smooth"),
		Material("nzombies-unlimited/hud/tally_3.png", "unlitgeneric smooth"),
		Material("nzombies-unlimited/hud/tally_4.png", "unlitgeneric smooth"),
		Material("nzombies-unlimited/hud/tally_5.png", "unlitgeneric smooth")
	}
	local tallyparticlepos = {
		{0,0,10,120},
		{45,0,10,120},
		{70,0,10,120},
		{115,0,-10,120},
		{115,0,-120,120},
	}

	local burnparticles = {
		Material("particle/particle_glow_03.vmt"),
		Material("particle/particle_glow_04.vmt"),
		Material("particle/particle_glow_05.vmt"),
		nil, -- I can't tell you why this is necessary, but it is
	}
	local burncolors = {
		--Color(255,255,255),
		--color_black,color_black,color_black,
		--Color(50,0,100),Color(10,0,50),Color(20,0,40),Color(50,0,20),Color(50,0,0), -- Purple shadows
		Color(50,0,0),Color(20,0,0),Color(10,0,0),Color(20,0,10),Color(50,10,0),Color(100,0,0),Color(150,0,0), -- Dark blood shadows

		Color(255,100,50),Color(255,100,0),Color(200,100,0),Color(255,100,50),Color(255,150,0), -- Burn colors
		nil,
	}
	local particlerate = 100
	local particlesize = 20
	local burnwidth = 10

	local particlespeed_x = 200
	local particlespeed_y = 100
	local particlelife = 1

	local whiterisespeed = 1.5
	local initialtime = 7
	local initialmove = 2

	local particles
	local lasttargetround = 0
	local lastparticletime
	local riser
	local initialcounter

	nzu.RegisterHUDComponentType("HUD_Round")
	nzu.RegisterHUDComponent("HUD_Round", "Unlimited", {
		Paint = function()
			local CT = CurTime()
			local r = ROUND:GetRound()
			local state = ROUND:GetState()

			if riser or state == ROUND_PREPARING and r ~= 1 then
				if not riser then riser = 0 end
				riser = riser + whiterisespeed*FrameTime()
				if riser > 1 and whiterisespeed > 0 then
					if state ~= ROUND_PREPARING then
						riser = nil
					else
						riser = 1
						whiterisespeed = -whiterisespeed
					end
				elseif riser < 0 and whiterisespeed < 0 then
					riser = 0
					whiterisespeed = -whiterisespeed
				end
			end

			if not riser and r ~= lastdrawnround then
				if not transitioncomplete or lasttargetround ~= r then
					transitioncomplete = CT + transitiontime
					particles = {}
					lasttargetround = r
					lastparticletime = CT
				end
				local pct = (transitioncomplete - CT)/transitiontime
				local pct2 = math.Clamp(transitioncomplete - 2 - CT, 0, 1)
				local invpct2 = 1 - pct2

				-- Special first round display
				local px,py = 75,ScrH()-175
				if r == 1 then
					if not initialcounter then
						initialcounter = CT + initialtime
					end

					local px2 = ScrW()/2 - tallysize/5
					local py2 = ScrH()/2
					if CT > initialcounter then
						local pct3 = 1 - (CT - initialcounter)/initialmove

						if pct3 <= 0 then
							initialcounter = nil
						else
							px = px + (px2 - px)*pct3
							py = py + (py2 - py)*pct3
							surface.SetTextColor(150, 0, 0, pct3*255)
						end
					else
						px = px2
						py = py2

						local fade = 255*pct2
						surface.SetTextColor(150 + 155*pct2, fade, fade)
					end

					surface.SetFont(font)
					local x,y = surface.GetTextSize("Round")
					surface.SetTextPos(ScrW()/2 - x/2, ScrH()/2 - y)
					surface.DrawText("Round")

					surface.SetMaterial(tallymats[1])
					surface.DrawTexturedRectUV(75, ScrH() - 175, tallysize, invpct2*tallysize, 0,0,1, invpct2)
				end

				if r <= 5 and r >= 0 then
					if lastdrawnround > r then
						lastdrawnround = 0
					elseif lastdrawnround <= 5 then
						local max = pct2*255
						surface.SetDrawColor(255,max,max)
						for i = 1, lastdrawnround do
							surface.SetMaterial(tallymats[i])
							surface.DrawTexturedRect(px, py, tallysize, tallysize)
						end
					end

					-- Transition with tally marks
					surface.SetDrawColor(255,pct*200,pct*100)

					local doneparticles
					for i = lastdrawnround + 1, r do
						surface.SetMaterial(tallymats[i])
						surface.DrawTexturedRectUV(px, py, tallysize, invpct2*tallysize, 0,0,1, invpct2)

						if invpct2 < 1 then
							local num = math.floor((CT - lastparticletime)*particlerate)
							if num > 0 then
								for j = 1,num do
									local x1,y1,x2,y2 = unpack(tallyparticlepos[i])
									local x = (x1 + x2*invpct2) + math.random(burnwidth) + px
									local y = (y1 + y2*invpct2) + py

									local mat = burnparticles[math.random(#burnparticles)]
									table.insert(particles, {
										X = x,
										Y = y,
										Material = mat,
										Color = burncolors[math.random(#burncolors)],
										SpeedX = math.random(-particlespeed_x, particlespeed_x),
										Time = CT
									})
								end
								doneparticles = true
							end
						end
					end

					if doneparticles then lastparticletime = CT end
				else
					surface.SetFont(font)

					-- Transition with number
					local max = 255*pct2
					if lastdrawnround <= 5 then
						surface.SetDrawColor(255,max,max,max)
						for i = 1, lastdrawnround do
							surface.SetMaterial(tallymats[i])
							surface.DrawTexturedRect(px, py, tallysize, tallysize)
						end
					else
						surface.SetTextPos(px + 25, py + 10)
						surface.SetTextColor(150 + 155*pct2,max,max,max)
						surface.DrawText(lastdrawnround)
					end

					if invpct2 < 1 then
						local x,y = surface.GetTextSize(r)

						render.ClearStencil()
						render.SetStencilEnable(true)
						local y1 = py + 10
						render.ClearStencilBufferRectangle(0, y1, 400, y1 + y*invpct2, 1)

						render.SetStencilReferenceValue(1)
						render.SetStencilCompareFunction(STENCIL_EQUAL)

						surface.SetTextColor(150 + pct*100,pct*250,pct*150,255)
						surface.SetTextPos(100, y1)
						surface.DrawText(r)

						render.SetStencilEnable(false)
						
						local num = math.floor((CT - lastparticletime)*particlerate*(x*0.1))
						if num > 0 then
							for j = 1,num do
								local x2 = math.random(x) + 100
								local y2 = y1 + y*invpct2

								local mat = burnparticles[math.random(#burnparticles)]
								table.insert(particles, {
									X = x2,
									Y = y2,
									Material = mat,
									Color = burncolors[math.random(#burncolors)],
									SpeedX = math.random(-particlespeed_x, particlespeed_x),
									Time = CT
								})
							end
							lastparticletime = CT
						end
					else
						surface.SetTextColor(150 + pct*100,pct*250,pct*150,255)
						surface.SetTextPos(px + 25, py + 10)
						surface.DrawText(r)
					end
				end

				for k,v in pairs(particles) do
					local diff = (CT - v.Time)
					local x = v.X
					local y = v.Y - particlespeed_y*diff

					surface.SetMaterial(v.Material)
					local col = v.Color
					surface.SetDrawColor(col.r, col.g, col.b, (1 - diff/particlelife) * 255)
					surface.DrawTexturedRect(x,y,particlesize,particlesize)

					v.X = v.X + v.SpeedX*FrameTime()
					v.SpeedX = v.SpeedX - (v.SpeedX*FrameTime()*3)
				end

				if not initialcounter and pct <= 0 then
					lastdrawnround = r
					transitioncomplete = nil
					particles = nil
					lastparticletime = nil
				end
			else
				if lastdrawnround > 5 then
					surface.SetFont(font)
					surface.SetTextPos(100, ScrH() - 165)

					if riser then
						local max = riser*255
						surface.SetTextColor(150 + riser*155,max,max)
					else
						surface.SetTextColor(150,0,0)
					end

					surface.DrawText(lastdrawnround)
				else
					if riser then
						local max = riser*255
						surface.SetDrawColor(255,max,max)
					else
						surface.SetDrawColor(255,0,0)
					end
					for i = 1, lastdrawnround do
						surface.SetMaterial(tallymats[i])
						surface.DrawTexturedRect(75, ScrH() - 175, tallysize, tallysize)
					end
				end
			end
		end
	})
end