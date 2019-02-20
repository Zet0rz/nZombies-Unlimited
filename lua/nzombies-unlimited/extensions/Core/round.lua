
local EXTENSION = nzu.Extension()
local ROUND = EXTENSION.Round or {}
local SETTINGS = EXTENSION.Settings

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
	if not ConVarExists("nzu_round_spawndelay") then CreateConVar("nzu_round_spawndelay", 0.25, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE}, "Sets the delay between each Zombie spawning.") end
	local max = GetConVar("nzu_round_maxzombies")
	local delay = GetConVar("nzu_round_spawndelay")

	util.AddNetworkString("nzu_round")
	local function donetwork()
		net.Start("nzu_round")
			net.WriteUInt(ROUND.Round, roundbits)
			net.WriteUInt(ROUND.State, 2)
		net.Broadcast()
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

	function ROUND:SpawnZombie()
		local z = ents.Create("npc_zombie")
		z:SetPos(Vector(0,0,0))
		z:SetHealth(self.ZombieHealth)

		self.NumberZombies = self.NumberZombies + 1
		self.ZombiesToSpawn = self.ZombiesToSpawn - 1
		self.Zombies[z] = true

		z:Spawn()
	end
	local function dozombiedeath(z)
		if ROUND.Zombies[z] then
			if z.nzu_Respawn then
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

	function ROUND:GetZombies()
		return table.GetKeys(self.Zombies)
	end

	local function startongoing()
		ROUND.State = ROUND_ONGOING
		donetwork()

		if not timer.Start("nzu_Round_Spawning") then
			timer.Create("nzu_Round_Spawning", delay:GetFloat(), 0, function()
				if ROUND.ZombiesToSpawn > 0 and ROUND.CurrentZombies < max:GetInt() then
					ROUND:SpawnZombie()
				end
			end)
		end

		PrintMessage(HUD_PRINTTALK, "Round starting!")
	end

	function ROUND:Prepare()
		self.State = ROUND_PREPARING
		donetwork()

		-- Change this later, the curve isn't quite accurate
		-- Based on the Z = 0.15*R x (24 + 6*[P-1])
		self.ZombiesToSpawn = math.Round(SETTINGS.ZombieNumberRoundScale * self.Round * (SETTINGS.ZombieNumberBase + SETTINGS.ZombieNumberPlayerScale * #self:GetPlayers()))
		self.ZombieHealth =
			self.Round < 10 and
				SETTINGS.ZombieHealthBase + SETTINGS.ZombieHealthScaleLinear*self.Round
			or
				-- 950 for round 10, multiply 1.1 for each round after. Read settings instead of static numbers
				(SETTINGS.ZombieHealthBase + SETTINGS.ZombieHealthScaleLinear*10)*(math.pow(SETTINGS.ZombieHealthScalePower, self.Round-10))


		self.CurrentZombies = 0
		self.Zombies = {}

		if not timer.Start("nzu_Round_Prepare") then
			timer.Create("nzu_Round_Prepare", 5, 1, startongoing)
		end
	end

	function ROUND:SetRound(num)
		timer.Stop("nzu_Round_Spawning")

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
end

if CLIENT then
	net.Receive("nzu_round", function()
		ROUND.Round = net.ReadUInt(roundbits)
		ROUND.State = net.ReadUInt(2)
	end)
end



--[[-------------------------------------------------------------------------
Player Management
We use Teams to network the players belonging to the round system or not
---------------------------------------------------------------------------]]
-- The "Unspawned". A mysterious class of people that seemingly has no interaction with the world, yet await their place in it.
team.SetUp(0, "Unspawned", Color(100,100,100))

function ROUND:SetUpTeam(...)
	local i = 1
	team.SetUp(i, ...)
	self.Team = i
end
function ROUND:GetPlayers() return team.GetPlayers(self.Team) end
function ROUND:GetPlayerCount() return team.NumPlayers(self.Team) end

if SERVER then
	function ROUND:AddPlayer(ply)
		ply:SetTeam(self.Team)
	end
	function ROUND:RemovePlayer(ply)
		ply:SetTeam(0)
	end

	function ROUND:SpawnPlayers()
		for k,v in pairs(self:GetPlayers()) do
			if not v:Alive() then
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
HUD Component
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
	EXTENSION.HUD.RegisterComponent(function()
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
	end)
end

-- Expose to other extensions
EXTENSION.Round = ROUND