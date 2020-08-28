AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.Category = "nZombies Unlimited"
ENT.Author = "Zet0r"
ENT.Spawnable = true

--[[-------------------------------------------------------------------------
This base provides a basic implementation of the Zombie AI. It supports:
- Spawn animations
- Attack animations
- Event handler system
- Basic barricades (by just attacking)
- Targeting and navigating

It DOES NOT support:
- Special barricade tear animations
- Movement speed-based animation decision

Use "nzu_zombie" for a COD-Zombie base that supports the above (but also requires
a model that has the appropriate animations)
---------------------------------------------------------------------------]]

--------------
-- Fields: Values that you can set for your subclass (or on initialize for the specific entity)
-- Callable: Functions you can call, but really shouldn't overwrite
-- Overridables: These can be overridden to make your own implementation and are called internally by the base. They all have a default (as seen here).
--------------

--[[-------------------------------------------------------------------------
Localization/optimization
---------------------------------------------------------------------------]]
local nzu = nzu
local getalltargetableplayers = nzu.GetAllTargetablePlayers
local CurTime = CurTime
local type = type
local Path = Path

local function validtarget(ent)
	return IsValid(ent) and ent:IsTargetable()
end

local coroutine = coroutine
local ents = ents
local math = math
local hook = hook

--[[-------------------------------------------------------------------------
Initialization
---------------------------------------------------------------------------]]
------- Fields -------

if CLIENT then
	-- Draw red eyes while the zombie is alive, as done in ENT:DrawEyeLight()
	-- Default draws at attachments "lefteye" and "righteye" or offset from "eyes"
	ENT.RedEyes = true
end

if SERVER then
	
	-- This is an example of how the Models table is defined (A Model, an optional Skin, and an optional set of Bodygroups)
	--[[ENT.Models = {
		{Model = "models/nzu/nzombie_honorguard.mdl", Skin = 0, Bodygroups = {0,0}},
		{Model = "models/nzu/nzombie_honorguard.mdl", Skin = 0, Bodygroups = {0,1}},
	}]]

	-- This should be the same as the model bounds to prevent the player from getting stuck in the zombie moving into us
	ENT.CollisionMins = Vector(-13,-13,0)
	ENT.CollisionMaxs = Vector(13,13,72)

	------- Overridables -------

	-- Lets you set the model of the zombie. By default, this fetches ENT.Models and randomly picks an entry.
	-- Later, "nzu_zombie" will get an override for this that fetches models from a Config Setting (Zombie Models setting)
	-- Extend this base if you want a generic solid Zombie NPC base, extend "nzu_zombie" if you want a normal zombie-like entity (like the skeletons in Der Eisendrache)
	function ENT:UpdateModel()
		local models = self.Models
		local choice = models[math.random(#models)]

		self:SetModel(choice.Model)
		if choice.Skin then self:SetSkin(choice.Skin) end
		if choice.Bodygroups then
			for k,v in pairs(choice.Bodygroups) do
				self:SetBodygroup(k,v)
			end
		end
	end

	-- 
	function ENT:UpdateMovementSequences()
		if self.SequenceTables then
			local t
			if self.SpeedBasedSequences then
				for k,v in pairs(self.SequenceTables) do
					if v.Threshold and v.Threshold > self.DesiredSpeed then break end
					t = v
				end
			else
				t = self.SequenceTables[math.random(#self.SequenceTables)]
			end

			if t then
				local seqs = t.Sequences[1] and t.Sequences[math.random(#t.Sequences)] or t.Sequences -- If Sequences is a numerical table, pick a random one (supports random selection)
				for k,v in pairs(seqs) do
					self[k] = v[math.random(#v)] -- Pick a random entry
				end
			end
		end
	end

	-- Called by the round when the Zombie spawns
	-- It is given the curve-based speed from Round as an argument
	-- but it can manage its own modifications if needed
	function ENT:SelectMovementSpeed(speed)
		return speed
	end

	-- Called when the speed is set on the zombie. This happens after SelectMovementSpeed
	-- You can use this to modify the zombie's behavior based on its speed
	-- Note: This isn't it's actual speed, but rather its desired speed
	-- In any normal circumstance, this is only called on spawn (but any ENT:SetDesiredSpeed call will ping this too)
	function ENT:SpeedChanged(speed)
		if self.SpeedBasedSequences then
			self:UpdateMovementSequences()
		end
	end

	-- Called by the round when the Zombie should have its health set
	-- It is given the curve-based health from Round as an argument
	-- You can return a result to override the zombie's health
	function ENT:SelectHealth(health)
		
	end
end

-- Called as the zombie is about to spawn right before it does
-- This is where you can set custom stats and other initialization parts
function ENT:Init() end

-- Called as the zombie spawns
-- Also called on respawns, so it's not always on initial creation!
function ENT:OnSpawn()
	if SERVER then self:TriggerEvent("Spawn") end
end

-- Called from ENT:SetupDataTables(). Allows you to set up more NetworkVars
-- than the built-in Bool "Alive" in slot 0 (don't use Bool slot 0)
function ENT:DataTables() end

--[[-------------------------------------------------------------------------
Targeting
---------------------------------------------------------------------------]]
if SERVER then
	------- Callables -------
	function ENT:GetTarget() return self.Target end -- Get the current target
	function ENT:SetTarget(t) if t == nil or self:AcceptTarget(t) then self.Target = t return true else return false end end -- Sets the target for the next path update
	AccessorFunc(ENT, "m_bTargetLocked", "TargetLocked", FORCE_BOOL) -- Stops the Zombie from retargetting and keeps this target while it is valid and targetable
	function ENT:SetNextRetarget(time) self.NextRetarget = CurTime() + time end -- Sets the next time the Zombie will repath to its target
	function ENT:Retarget() -- Causes a retarget
		if self:GetTargetLocked() and validtarget(self.Target) then return end

		local target, dist = self:SelectTarget()
		if target ~= self.Target then
			self:ForceRepath()
		end
		self.Target = target
		self:SetNextRetarget(self:CalculateNextRetarget(target, dist))
	end

	------- Overridables -------

	-- Lets you determine what targets this Zombie can go for
	-- Allows immunity to specific SetTargets, such as Monkey Bombs or Gersch Devices
	function ENT:AcceptTarget(t)
		return t:IsTargetable()
	end

	-- Lets your determine what target to go for next upon retargeting
	function ENT:SelectTarget()
		local mindist = math.huge
		local target
		for k,v in pairs(getalltargetableplayers()) do
			local d = self:GetRangeTo(v)
			if d < mindist and self:AcceptTarget(v) then
				target = v
				mindist = d
			end
		end

		return target, mindist
	end

	-- Lets you determine how long until the next retarget
	-- This is called after a retarget. You can use the distance, it is known to be the smallest distance to all players
	function ENT:CalculateNextRetarget(target, dist)
		return math.Clamp(dist/200, 3, 15) -- 1 second for every 100 units to the closet player
	end

	-- Called from RunBehaviour when there is no valid target
	-- This lets you do your own custom logic
	-- Remember that retargeting is automatic if the next retarget cycle is past
	function ENT:OnNoTarget()
		self:Timeout(2)
	end
end

--[[-------------------------------------------------------------------------
Pathing - SERVER
---------------------------------------------------------------------------]]

if SERVER then
	------- Fields -------
	ENT.Acceleration = 500
	ENT.Deceleration = 1000
	ENT.JumpHeight = 60
	ENT.MaxYawRate = 360
	ENT.StepHeight = 18

	------- Callables -------
	function ENT:ForceRepath() self.NextRepath = 0 end -- Forces the Zombie to recompute its path next tick
	function ENT:SetNextRepath(time) self.NextRepath = time end -- Sets how long until the next time the bot will repath. Relative to current path's age

	function ENT:LockTargetPosition(pos) self.LockedTargetPosition = pos end -- Lock to a new target location, rather than self.Target's location
	function ENT:GetTargetPosition() return self.LockedTargetPosition or self:SelectTargetPosition() end -- Get the current goal location. Supports locked goal locations
	function ENT:GetLockedTargetPosition() return self.LockedTargetPosition end -- Gets whether there is a locked target location or not (and which if so)

	function ENT:TerminatePath() self.Path = nil end -- Forces the Zombie to re-initialize its pathing. You shouldn't have to ever call this

	-- Returns to normal movement sequence. Call this in events where you want to MoveToPos after an animation
	function ENT:ResetMovementSequence()
		self:ResetSequence(self.MovementSequence)
	end

	-- Simple, get the current goal position of the path, including tolerance
	function ENT:GetCurrentGoal() return IsValid(self.Path) and self.Path:GetCurrentGoal() end

	-- Returns whether the current path goal exists and it is in the same 180-degree direction as the argument position
	function ENT:IsMovingTowards(pos)
		return (pos - self:GetPos()):Dot(self.loco:GetGroundMotionVector()) > 0
	end

	-- Opposite of above. But instead of using 'not', this would return false if we don't have a path at all (arbitrary what direction we move - we'll always move towards the target pos)
	function ENT:IsNotMovingTowards(pos)
		return (pos - self:GetPos()):Dot(self.loco:GetGroundMotionVector()) < 0
	end

	-- Same as above, but directly returns the number. You can do whatever you want with it. This one is normalized
	function ENT:GetMotionDot(pos)
		return (pos - self:GetPos()):GetNormalized():Dot(self.loco:GetGroundMotionVector())
	end

	------- Overridables -------
	-- function ENT.ComputePath() end -- This is commented out as the default is 'nil' (default path generator)

	-- Called after a repath. This lets you determine how long before the bath should be recomputed
	-- It is a good optimization idea to base this off of the prior path's length
	function ENT:CalculateNextRepath(path)
		-- Get the target player's max running speed
		local targetspeed = IsValid(self.Target) and self.Target:IsPlayer() and self.Target:GetRunSpeed() or self.DesiredSpeed

		-- Our path delay should be the time it'd take this zombie and its target to move the path together (both run to each other)
		local result = path:GetLength()/(self.DesiredSpeed + targetspeed)

		-- Clamp that result between 1 and 10 seconds
		return math.Clamp(result, 1, 10)
	end

	-- Called when the bot recomputes its path and needs to find its target location
	-- Assume self.Target is valid unless you overwrite the AI functions
	-- Here you can do things such as determine your own locations that might not be right on the target
	function ENT:SelectTargetPosition()
		return self.Target:GetPos()
	end
end

--[[-------------------------------------------------------------------------
Attacking
---------------------------------------------------------------------------]]
if SERVER then
	------- Fields -------
	AccessorFunc(ENT, "m_bAttackBlocked", "BlockAttack", FORCE_BOOL) -- Stops the Zombie from attacking

	ENT.AttackDamage = 30
	ENT.AttackRange = 60

	-- How much of the movement speed is looked ahead to determine an attack range while moving
	-- This is therefore roughly equal to the average Impact time of attacks (see AttackSequences table)
	-- Setting to 0 will make the Zombie unable to move while attacking (only attack on full Path end)
	ENT.MovementAttackRange = 0.5

	-- List of different attack sequences, and the cycle at which they impact (Example table)
	-- Impacts are in cycle (0-1), the percentage through the sequence
	-- It may contain multiple entries, at which point the Zombie will hit multiple times
	-- They must be sequential.
	-- These are also used for ENT:DoAttackFunction(), only first if 'multihit' is not true
	--[[ENT.AttackSequences = {
		{Sequence = "swing", Impacts = {0.5}}
	}]]

	-- List of attack sounds (Example table)
	--[[ENT.AttackSounds = {
		Sound("nzu/zombie/attack/attack_00.wav"),
		Sound("nzu/zombie/attack/attack_01.wav"),
		Sound("nzu/zombie/attack/attack_02.wav"),
		Sound("nzu/zombie/attack/attack_03.wav"),
		Sound("nzu/zombie/attack/attack_04.wav"),
		Sound("nzu/zombie/attack/attack_05.wav"),
		Sound("nzu/zombie/attack/attack_06.wav"),
		Sound("nzu/zombie/attack/attack_07.wav"),
		Sound("nzu/zombie/attack/attack_08.wav"),
		Sound("nzu/zombie/attack/attack_09.wav"),
		Sound("nzu/zombie/attack/attack_10.wav"),
		Sound("nzu/zombie/attack/attack_11.wav"),
		Sound("nzu/zombie/attack/attack_12.wav"),
		Sound("nzu/zombie/attack/attack_13.wav"),
		Sound("nzu/zombie/attack/attack_14.wav"),
		Sound("nzu/zombie/attack/attack_15.wav"),
	}]]

	------- Callables -------

	-- Gets the zombie's current attack range based on its movement speed
	-- Should be used when attempting to make a moving attack
	-- Use ENT.AttackRange to get static attack range
	function ENT:GetMovementAttackRange()
		return self.AttackRange + self.DesiredSpeed*self.MovementAttackRange
	end

	-- Perform an attack
	-- It selects an attack animation and plays it, dealing damage during its moments of impact
	-- A damage info can be passed, otherwise a default is created
	function ENT:AttackTarget(target, move)
		if not self:GetBlockAttack() and IsValid(target) then

			-- Perform the attack with the function of hurting the target!
			if move then
				self:DoMovingAttackFunction(target, function(self, target)
					if self:GetRangeTo(target) <= self.AttackRange then
						local dmg = DamageInfo()
						dmg:SetDamage(self.AttackDamage)
						dmg:SetDamageType(DMG_SLASH)
						local dir = (target:GetPos() - self:GetPos())
						dmg:SetDamageForce(dir:GetNormalized() * 10)
						dmg:SetDamagePosition(target:GetPos())
						dmg:SetAttacker(self)
						dmg:SetInflictor(self)
						
						target:TakeDamageInfo(dmg)
					end
				end, true)
			else
				self:DoAttackFunction(target, function(self, target)
					if self:GetRangeTo(target) <= self.AttackRange then
						local dmg = DamageInfo()
						dmg:SetDamage(self.AttackDamage)
						dmg:SetDamageType(DMG_SLASH)
						local dir = (target:GetPos() - self:GetPos())
						dmg:SetDamageForce(dir:GetNormalized() * 10)
						dmg:SetDamagePosition(target:GetPos())
						dmg:SetAttacker(self)
						dmg:SetInflictor(self)
						
						target:TakeDamageInfo(dmg)
					end
				end, true)
			end
		end
	end

	-- Plays an attack animation and at the moment of impact, executes the function
	-- This should only be called in an event handler (or otherwise in the bot's coroutine)
	function ENT:DoAttackFunction(target, func, multihit, speed)
		local speed = speed or 1

		local attack = self:SelectAttack(target)
		self:FaceTowards(target:GetPos())

		local seqdur = self:SetSequence(attack.Sequence)/speed
		self:ResetSequenceInfo()
		self:SetCycle(0)
		self:SetPlaybackRate(speed)

		-- Play the attack sound (which also stops further calls to ENT:Sound() until it is done + delay)
		if self.AttackSounds then self:PlaySound(self.AttackSounds[math.random(#self.AttackSounds)]) end

		if multihit then
			-- Support using multiple hit times
			local lasttime = 0
			local n = #attack.Impacts
			for i = 1,n do
				local delay = seqdur*attack.Impacts[i]
				coroutine.wait(delay - lasttime)
				func(self, target) -- Call the function
				lasttime = delay
			end
			coroutine.wait(seqdur - lasttime)
		else
			-- Only execute with the first hit
			local time = attack.Impacts[1]
			coroutine.wait(seqdur*time)
			func(self, target)
			coroutine.wait(seqdur*(1 - time))
		end
	end

	-- Plays an attack animation similarly to above, but will move towards its target on a frequently recomputed path
	-- Fifth argument are options similar to MoveToPos
	function ENT:DoMovingAttackFunction(target, func, multihit, speed, options)
		local speed = speed or 1

		local attack = self:SelectAttack(target)
		self:FaceTowards(target:GetPos())

		local seqdur = self:SetSequence(attack.Sequence)/speed
		self:ResetSequenceInfo()
		self:SetCycle(0)
		self:SetPlaybackRate(speed)

		-- Play the attack sound (which also stops further calls to ENT:Sound() until it is done + delay)
		if self.AttackSounds then self:PlaySound(self.AttackSounds[math.random(#self.AttackSounds)]) end

		local options = options or {}
		local compute = self.ComputePath
		local path = Path("Follow")
		path:SetMinLookAheadDistance(options.lookahead or 1)
		path:SetGoalTolerance(options.tolerance or 1)
		path:Compute(self, target:GetPos(), compute)

		local repath = options.repath or 0.25
		local function movealong(time) -- A copy of coroutine.wait, but allowing the path to be updated
			local goal = CurTime() + time
			while true do
				if goal < CurTime() then return end
				if IsValid(path) then
					path:Update(self)
					--path:Draw() -- DEBUG
				end
				if path:GetAge() > repath then path:Compute(self, target:GetPos(), compute) end
				coroutine.yield()
			end
		end

		self:StartMovingAttack(target, attack, speed)

		if multihit then
			-- Support using multiple hit times
			local lasttime = 0
			local n = #attack.Impacts
			for i = 1,n do
				local delay = seqdur*attack.Impacts[i]
				movealong(delay - lasttime)
				func(self, target) -- Call the function
				lasttime = delay
			end
			movealong(seqdur - lasttime)
		else
			-- Only execute with the first hit
			local time = attack.Impacts[1]
			movealong(seqdur*time)
			func(self, target)
			movealong(seqdur*(1 - time))
		end

		self:FinishMovingAttack()
	end

	------- Overridables -------

	-- Select which attack sequence table to use for an upcoming attack
	-- This can be dependant on the target, but could also be anything
	-- We just pick a random in the AttackSequences table here
	function ENT:SelectAttack(target)
		return self.AttackSequences[math.random(#self.AttackSequences)]
	end

	-- Lets you apply various effects to moving attacks
	-- This is the place where you'll want to adjust movement speed if you want a small slowdown
	-- The base merely applies insane acceleration to make the zombie always able to keep up
	function ENT:StartMovingAttack(target, attack, speed)
		--self.loco:SetAcceleration(10000)
	end

	-- Called at the end of a moving attack
	-- This is where you'll want to revert the changes made in ENT:StartMovingAttack
	function ENT:FinishMovingAttack()
		--self.loco:SetAcceleration(self.Acceleration)
	end
end

--[[-------------------------------------------------------------------------
Spawn, Deaths, Point Callbacks
Callback for when the Zombie dies, or should give points to a player
---------------------------------------------------------------------------]]
if SERVER then
	------- Fields -------

	-- A list of sounds to play on death
	--[[ENT.DeathSounds = {
		Sound("nzu/zombie/death/death_00.wav"),
		Sound("nzu/zombie/death/death_01.wav"),
		Sound("nzu/zombie/death/death_02.wav"),
		Sound("nzu/zombie/death/death_03.wav"),
		Sound("nzu/zombie/death/death_04.wav"),
		Sound("nzu/zombie/death/death_05.wav"),
		Sound("nzu/zombie/death/death_06.wav"),
		Sound("nzu/zombie/death/death_07.wav"),
		Sound("nzu/zombie/death/death_08.wav"),
		Sound("nzu/zombie/death/death_09.wav"),
		Sound("nzu/zombie/death/death_10.wav"),
	}]]
	
	-- The amount of force to skip the death animation and do a ragdoll instead
	-- Set to 0 to always ragdoll, -1 to never
	ENT.DeathRagdollForce = 0
	
	-- A table of death animations. Will play if the force of the damage is below ENT.DeathRagdollForce
	-- Default: nil (since the base always ragdolls)
	--ENT.DeathAnimations = nil

	------- Callables -------

	-- Performs an animation and dies. This overwrites the RunBehaviour routine, and thus will instantly cancel any and all events
	-- Events must be coded with this in mind!
	function ENT:DoDeathAnimation(seq)
		self.BehaveThread = coroutine.create(function()
			self:PlaySequenceAndWait(seq)
			self:BecomeRagdoll(DamageInfo())
		end)
	end

	------- Overridables -------

	-- Called when the Zombie is about to die, right before ENT:PerformDeath.
	-- If you want to perform specific logic on the zombie dying, this is where
	-- Default: Do nothing really
	function ENT:OnDeath(dmg)
		
	end

	-- Called when the bot wants to perform a death. Become ragdoll or otherwise perform a death animation here
	-- Default: Fling like a ragdoll based on the damage and play a death sound!
	function ENT:PerformDeath(dmg)
		self:PlaySound(self.DeathSounds[math.random(#self.DeathSounds)])
		if self.DeathRagdollForce == 0 or self.DeathRagdollForce <= dmg:GetDamageForce():Length() then
			self:BecomeRagdoll(dmg)
		else
			self:DoDeathAnimation(self.DeathAnimations[math.random(#self.DeathAnimations)])
		end
	end


	-- Select a spawn sequence and sound to play. This is called after everything is initialized
	-- so it can be made dependant on certain properties defined on spawning
	-- If ENT.SpawnSequence is a table, we pick a random one
	function ENT:SelectSpawnSequence()
		local s
		if self.SpawnSounds then s = self.SpawnSounds[math.random(#self.SpawnSounds)] end
		return type(self.SpawnSequence) == "table" and self.SpawnSequence[math.random(#self.SpawnSequence)] or self.SpawnSequence, s
	end

	-- Perform the actual spawn. This can be overwritten if you want to do something COMPLETELY
	-- different for the spawn. This is running during the bot's "Spawn" event
	function ENT:Event_Spawn()
		local seq,s = self:SelectSpawnSequence()
		if seq then
			self:PlaySequenceAndWait(seq)
		end
		if s then self:PlaySound(s) end
	end
end

--[[-------------------------------------------------------------------------
Vaults
Similar to attacks, these are just fields along with a SelectVault function
---------------------------------------------------------------------------]]
if SERVER then
	------- Fields -------
	--ENT.VaultSequence = {Sequence = "nz_barricade_walk_1", Speed = 30} -- What animation to vault with

	------- Overridables -------
	-- Select a vault sequence based on the target location
	function ENT:SelectVaultSequence(pos)
		local seq = self.VaultSequence[1] and self.VaultSequence[math.random(#self.VaultSequence)] or self.VaultSequence
		return seq.Sequence, seq.Speed
	end
end

--[[-------------------------------------------------------------------------
Events
Functions prefixed with Event_ will act as Event Functions and will be triggered
by ENT:TriggerEvent(ID) [Runs ENT:Event_ID]
Every event can take 1 argument; the data passed from the TriggerEvent call

Any time an event is triggered that doesn't exist as a function on ENT, the
entity triggering it will likely have a generic default that runs instead

You only need to create the functions where you want custom behavior
---------------------------------------------------------------------------]]
if SERVER then
	------- Callables -------
	function ENT:GetCurrentEvent() return self.ActiveEvent end -- Returns the string ID of the currently played event, if any
	function ENT:GetInteractingEntity() return self.nzu_InteractTarget end -- Returns the entity the zombie is currently interacting with, if any. This is only set from ENTITY:ZombieInteract on entities the zombie walks into
	function ENT:SolidMaskDuringEvent(mask)  -- Changes the zombie's mask until the end of the event. If nil is passed, it immediately removes the mask
		if mask then
			self:SetSolidMask(mask)
			self.EventMask = true
		else
			self:SetSolidMask(MASK_NPCSOLID)
			self.EventMask = nil
		end
	end

	function ENT:CollideWhenPossible() self.DoCollideWhenPossible = true end -- Make the zombie solid again as soon as there is space

	-- Set the Event End function. This is called automatically when the event is ended, but can also be called manually in said event
	-- For example, this is used by Barricades where they reserve a spot and a plank, and the terminate function un-reserves those spots
	--function ENT:EventEndFunction(f) self.TerminateEventFunction = f end
	--function ENT:ExecuteEventEndFunction() if self.TerminateEventFunction then self:TerminateEventFunction() self.TerminateEventFunction = nil end

	function ENT:InteractCooldown(time) self.NextInteract = CurTime() + time end -- Pauses Interaction for this zombie for a set time. It will still move, but won't trigger ZombieInteract's

	------- Basic Events -------

	-- Perform a basic attack on the given target
	-- We do a moving attack if the target is a player
	function ENT:Event_Attack(target)
		local t = target or self.Target
		self:AttackTarget(t, t:IsPlayer())
	end

	-- Perform a basic vault to a target position
	function ENT:Event_Vault(pos)
		local from
		local to
		if type(pos) == "table" then
			from = pos.From
			to = pos.To
		else
			to = pos
		end

		if self:IsNotMovingTowards(to) then return end -- Don't vault at all if the direction of vault is away from where we want to go

		self:SolidMaskDuringEvent(MASK_NPCSOLID_BRUSHONLY) -- Nocollide with props and other entities while we attempt to vault (Gets removed after event, or with CollideWhenPossible)
		local stucktime

		-- If from exists, move to that position first
		if from then
			self:ResetMovementSequence()
			local path = Path("Follow")
			path:SetGoalTolerance(20)
			path:SetMinLookAheadDistance(10)
			path:Compute(self, from, self.ComputePath)

			while path:IsValid() do
				if self:ShouldEventTerminate() then return end -- We support terminating the event only before the vault

				path:Update(self)
				if self:IsStuck() then
					if not stucktime then
						stucktime = CurTime() + 2
					elseif stucktime < CurTime() then
						return -- Give up
					end
				elseif stucktime then -- Resume the vault
					stucktime = nil
				end
				coroutine.yield()
			end

			self:SetPos(from)
		end
		stucktime = nil

		-- Get a path to the target location so we can get the distance
		local path = Path("Follow")
		path:SetGoalTolerance(10)
		path:Compute(self, to, self.ComputePath)
		if not path:IsValid() then return end

		local name,groundspeed = self:SelectVaultSequence(to)
		if not groundspeed then groundspeed = self.VaultSpeed end
		local seq,dur = self:LookupSequence(name)

		local dist = path:GetLength()
		self:ResetSequence(seq)
		self:SetCycle(0)

		local rate = dur/(dist/groundspeed)
		self:SetPlaybackRate(rate)
		local t = CurTime()

		self.loco:SetAcceleration(500)
		self.loco:SetDesiredSpeed(groundspeed)

		local isdone = false
		while path:IsValid() do
			path:Update(self)

			if self:IsStuck() then
				if not stucktime then
					stucktime = CurTime() + 2
					self:SetPlaybackRate(0)
				elseif stucktime < CurTime() then
					self:SetPos(to) -- Give up and teleport
					break
				end
			elseif stucktime then -- Resume the vault
				stucktime = nil
				self:SetPlaybackRate(rate)
			end
			coroutine.yield()
			if self:GetCycle() == 1 and not isdone then
				self:ResetMovementSequence()
				isdone = true
			end
		end

		self.loco:SetAcceleration(self.Acceleration)
		self.loco:SetDesiredSpeed(self.DesiredSpeed)
		self:CollideWhenPossible() -- Remove the mask as soon as we can
	end
end

--[[-------------------------------------------------------------------------
Anti-Stuck
Functions and callables relating to being stuck or getting obstructing entities
---------------------------------------------------------------------------]]
if SERVER then
	------- Fields -------
	ENT.StuckDelay = 1 -- How long the zombie must remain still to begin counting as stuck
	ENT.UnStuckDelay = 0.5 -- How long the zombie must have gone without a stuck update to be considered unstuck
	ENT.MaxStuckTime = 5 -- How long to be stuck for for the zombie to give up and call ENT:OnFullyStuck()
	ENT.RandomPushForce = 200 -- How powerful a ENT:ApplyRandomPush() is when supplied no arguments

	------- Callables -------

	-- Applies a push to the locomotion of the the zombie in a random direction
	-- If force is not supplied, ENT.RandomPushForce is used
	function ENT:ApplyRandomPush(force)
		local force = force or self.RandomPushForce
		self.loco:SetVelocity(self.loco:GetVelocity() + VectorRand()*force)
	end

	function ENT:IsStuck() return self.FullyStuckTime and true or false end -- Get whether the bot is stuck. This is not always equal to self.loco:IsStuck()
	function ENT:GetStuckEntity() return self.CurrentlyStuckEntity end -- Get the entity the bot is stuck on. This is updated once every 0.5 seconds in OnContact and remains until OnUnStuck

	-- Clears the stuck on the entity. It clears it on the loco if it is stuck, otherwise just on the bot
	-- (the loco will also call OnUnStuck on the bot if it is stuck, so we prevent double-call)
	function ENT:ClearStuck()
		if self.loco:IsStuck() then
			self.loco:ClearStuck()
		else
			self:OnUnStuck()
		end
	end

	------- Overridables -------

	-- Called when the Zombie is stuck and attempting to handle it
	-- Runs continuously as the zombie remains stuck
	-- Default: Perform random pushes at the interval specified in StuckPushDelay
	function ENT:Stuck()
		if not self.NextRandomPush or CurTime() > self.NextRandomPush then
			self:ApplyRandomPush()
			self.NextRandomPush = CurTime() + 0.5
		end
	end

	-- Called when the Zombie is stuck for longer than MaxStuckTime
	-- You can call self.loco:ClearStuck() here for the timer to reset if you want
	-- Default: Respawn the zombie completely
	function ENT:OnFullyStuck()
		self:Respawn()
	end



	------- Internals -------
	-- You really shouldn't overwrite these unless you know what you're doing
	-- Called from the Nextbot itself when stuck. Handles the calling of ENT:Stuck() and ENT:OnFullyStuck()
	-- You can overwrite these if you don't want that system, but just want your own
	
	-- Perform the two functions based on the time
	function ENT:HandleStuck()
		if self.ActiveEvent then return end
		if self.FullyStuckTime and CurTime() > self.FullyStuckTime then
			self:OnFullyStuck()
		else
			self:Stuck()
		end
	end

	-- Initialize the time
	function ENT:OnStuck()
		if not self.FullyStuckTime then self.FullyStuckTime = CurTime() + self.MaxStuckTime end
	end

	-- Reset the time
	function ENT:OnUnStuck()
		self.FullyStuckTime = nil
		self.AboutToBeUnStuck = nil
		self.AboutToBeStuck = nil
		self.CurrentlyStuckEntity = nil
	end
end

--[[-------------------------------------------------------------------------
AI
A stack of functions that are called from the bot's RunBehaviour
These let you modify the bot's AI and behavior completely
---------------------------------------------------------------------------]]

------- Callables -------
function ENT:Alive() return self:GetAlive() end -- Pretty obvious

if SERVER then
	------- Overridables -------

	-- When a path ends. Either when the goal is reached, or when no path could be found
	-- This is where you should trigger your attack event or idle
	function ENT:OnPathEnd()
		if not self:GetBlockAttack() and IsValid(self.Target) and self:AcceptTarget(self.Target) then
			if self:GetRangeTo(self.Target) <= self.AttackRange then
				self:TriggerEvent("Attack", self.Target)
			end
		else
			self:Timeout(2)
		end
	end

	-- When the path is terminated from either reaching its end or ENT:TerminatePath() is called
	-- Allows you to change the definition of what the bot initially does when it needs to "start" over
	-- Default: Generate a path to its target and set a movement sequence
	function ENT:InitializePath()
		local path = Path("Follow")
		self.Path = path

		path:SetMinLookAheadDistance(self.AttackRange)
		path:SetGoalTolerance(30)

		path:Compute(self, self:GetTargetPosition(), self.ComputePath)
		self:SetNextRepath(self:CalculateNextRepath(path))
		self:ResetMovementSequence()
	end

	-- Called while a path is valid and right after the bot has moved along the path
	-- Lets you do things such as decide to randomly stop or change targets and recompute
	-- Note: Called at the end of the coroutine. Any events triggered from here will happen immediately next cycle
	-- Note 2: This is called in every loop - use some delay measure to not spam expensive functions
	-- Default: Do nothing (just move along the path)
	function ENT:AI()

	end

	-- Called when the zombie collides with a non-target player according to its collision boxes
	-- You can use this to call attacks before the end of the path is reached
	-- Default: Change targets and attack if successful!
	-- Note: If the player is the target, ENT:InteractTarget is called instead!
	function ENT:InteractPlayer(ply)
		if not self:GetBlockAttack() and self:SetTarget(ply) then -- If we succeeded in targetting this player
			self:TriggerEvent("Attack", ply)
		end
	end

	-- Called when the zombie collides with the target. Note that this isn't necessarily a player!
	-- Monkey bombs and other target entities go here as well
	-- Default: Attack the target! (Even if it is a non-player!)
	function ENT:InteractTarget(target)
		if not self:GetBlockAttack() then self:TriggerEvent("Attack", target) end
	end

	-- Called when bumping into any entity that doesn't have a ZombieInteract function and isn't a player
	-- This is not affected by "zombie proxying", so it cannot be used to detect walking into a crowd of zombies
	-- interacting with something else. You can use this to make special interactions that only this zombie can do
	-- Default: Do nothing (ignore it)
	function ENT:Interact(ent)

	end
end


--[[-------------------------------------------------------------------------
Sound
Only applies to passive sounds - if you want attack or action-based sounds,
you need to play those yourself in your functions (see Attack section for example)
---------------------------------------------------------------------------]]
if SERVER then
	------- Fields -------
	ENT.SoundDelayMin = 2
	ENT.SoundDelayMax = 4
	ENT.BehindSoundDistance = 0 -- The distance to a target where we will play "behind sounds" instead (0 = disable). This requires ENT.BehindSounds to be set

	-- Sounds that play through the AI (Example commented out table)
	--[[ENT.PassiveSounds = {
		Sound("nzu/zombie/amb/amb_00.wav"),
		Sound("nzu/zombie/amb/amb_01.wav"),
		Sound("nzu/zombie/amb/amb_02.wav"),
		Sound("nzu/zombie/amb/amb_03.wav"),
		Sound("nzu/zombie/amb/amb_04.wav"),
		Sound("nzu/zombie/amb/amb_05.wav"),
	}]]

	------- Callables -------

	-- Play a sound and delay the next passive sound by this amount
	-- Optionally manually define delay, rather than random number
	function ENT:PlaySound(s, lvl, pitch, vol, chan, delay)
		local delay = delay or math.Rand(self.SoundDelayMin, self.SoundDelayMax)
		if s then
			local dur = SoundDuration(s)
			self:EmitSound(s, lvl, pitch, vol, chan)
			delay = delay + dur
		end
		self.NextSound = CurTime() + delay
	end


	------- Overridables -------

	-- Perform sound play logic. This is called repeatedly once the delay of a PlaySound is over
	-- If BehindSoundDistance is set to an above-0 value, when the zombie is within this range to its target and that target is a player
	-- then it will instead play a sound from ENT.BehindSounds, at a louder level
	-- Otherwise it will play one from PassiveSounds if that exists

	function ENT:Sound()
		if self.BehindSoundDistance > 0 -- We have enabled behind sounds
			and IsValid(self.Target)
			and self.Target:IsPlayer() -- We have a target and it's a player within distance
			and self:GetRangeTo(self.Target) <= self.BehindSoundDistance
			and (self.Target:GetPos() - self:GetPos()):GetNormalized():Dot(self.Target:GetAimVector()) >= 0 then -- If the direction towards the player is same 180 degree as the player's aim (away from the zombie)
				self:PlaySound(self.BehindSounds[math.random(#self.BehindSounds)], SNDLVL_140) -- Play the behind sound, and a bit louder!
		elseif self.PassiveSounds then
			self:PlaySound(self.PassiveSounds[math.random(#self.PassiveSounds)])
		else
			-- We still delay by max sound delay even if there was no sound to play
			self.NextSound = CurTime() + self.SoundDelayMax
		end
	end
end


--[[-------------------------------------------------------------------------
Misc Events and "Perform" functions
Perform functions are functions that initialize some action
---------------------------------------------------------------------------]]
if SERVER then
	------- Fields -------
	ENT.IdleSequence = "nz_idle_ad"

	------- Overridables -------

	-- Called when the zombie wants to idle. Play an animation here
	function ENT:PerformIdle()
		self:ResetSequence(self.IdleSequence)
	end
end

--[[-------------------------------------------------------------------------
Core
Below here is the base code that you shouldn't override
(but you still can if you really want to)
---------------------------------------------------------------------------]]
function ENT:Initialize()
	if SERVER then
		self:SetLagCompensated(true)
		self:UpdateModel()
		self:SetCollisionBounds(self.CollisionMins, self.CollisionMaxs)

		self:SetNextRepath(0)
		self:SetNextRetarget(0)

		self.loco:SetAcceleration(self.Acceleration)
		self.loco:SetDeceleration(self.Deceleration)
		self.loco:SetJumpHeight(self.JumpHeight)
		self.loco:SetMaxYawRate(self.MaxYawRate)
		self.loco:SetStepHeight(self.StepHeight)

		if not self.SpeedBasedSequences then self:UpdateMovementSequences() end -- If SpeedBasedSequences WAS true, it would do this in SpeedChanged (unless overwritten)
		self:SetAlive(true)
	end

	self:Init()
	self:OnSpawn()
end

if SERVER then
	function ENT:SetDesiredSpeed(speed)
		self.DesiredSpeed = self:SelectMovementSpeed(speed)
		self.loco:SetDesiredSpeed(self.DesiredSpeed)
		self:SpeedChanged(self.DesiredSpeed)
	end

	function ENT:RunBehaviour()
		self:Retarget()
		if IsValid(self.Target) then self:InitializePath() end

		while true do
			if self.ActiveEvent then
				self:EventHandler(self.EventData) -- This handler should be holding the routine until it is done

				self.ActiveEvent = nil
				self.EventData = nil

				if self.EventMask and not self.DoCollideWhenPossible then
					self:SetSolidMask(MASK_NPCSOLID)
					self.EventMask = nil
				end

				local interacting = self.nzu_InteractTarget
				if IsValid(interacting) then
					if interacting.ZombieInteractEnd then interacting:ZombieInteractEnd(self) end
					self.nzu_InteractTarget = nil -- Remove the proxy if any
				end

				self:ResetMovementSequence()

				if self.loco:IsStuck() then self.FullyStuckTime = CurTime() + self.MaxStuckTime end
			end

			local ct = CurTime()
			if ct >= self.NextRetarget then
				local oldtarget = self.Target
				self:Retarget()
				if self.Target ~= oldtarget then
					self:SetNextRepath(0) -- Immediately repath next cycle
				end
			end

			if not IsValid(self.Target) then
				self.Path = nil
				self:OnNoTarget()
			else
				local path = self.Path
				if not path then
					self:InitializePath()
					path = self.Path
				elseif not IsValid(path) then -- We reached the goal, or path terminated for another reason
					self:OnPathEnd()

					if not IsValid(self.Target) or not self:AcceptTarget(self.Target) then
						self:Retarget() -- Retarget on path end if the previous target is no longer valid
						if not IsValid(self.Target) or not self:AcceptTarget(self.Target) then continue end
					end

					-- Recompute the path
					path:Compute(self, self:GetTargetPosition(), self.ComputePath)
					self:SetNextRepath(self:CalculateNextRepath(path))
				end

				if path:GetAge() >= self.NextRepath then
					if not IsValid(self.Target) then
						self:SetNextRetarget(0) -- Retarget next cycle
						coroutine.yield()
						continue
					end
					path:Compute(self, self:GetTargetPosition(), self.ComputePath)
					self:SetNextRepath(self:CalculateNextRepath(path))
				end
				-- DEBUG
				--path:Draw()
				path:Update(self)
				if self:IsStuck() then self:HandleStuck() end

				if not self.NextSound or self.NextSound < CurTime() then
					self:Sound()
				end

				self:AI()
			end

			coroutine.yield()
		end
	end

	ENT.CollisionBoxCheckInterval = 1
	ENT.StuckCheckInterval = 0.5
	local boxcheckrange = 30
	local boxa,boxb = Vector(-16,-16,0), Vector(16,16,64)
	function ENT:OnContact(ent)
		if not self.ActiveEvent and IsValid(ent) then
			local CT = CurTime()

			if not self.NextInteract or self.NextInteract <= CT then
				self.NextInteract = nil

				local ent2 = ent.nzu_InteractTarget or ent -- Bumping into a proxy interactor
				if ent2.ZombieInteract then
					self.nzu_InteractTarget = ent2 -- Turn ourselves into a proxy for the duration of the interaction
					ent2:ZombieInteract(self, ent)

					-- Remove our proxy only if the interaction did not cause an event
					-- Otherwise, the end of the event will remove the proxy
					if not self.ActiveEvent then
						self.nzu_InteractTarget = nil
						if ent2.ZombieInteractEnd then ent2:ZombieInteractEnd(self) end
					end
					return
				end
				if ent2 == self.Target then self:InteractTarget(ent2, ent) return end
				if ent2:IsPlayer() then self:InteractPlayer(ent2, ent) return end

				-- The entity or its proxy did not pass any of the interactions
				-- Attempt to find an interactable entity in a box 30 units ahead of us
				if not self.NextBoxCheck or self.NextBoxCheck < CT then
					self.NextBoxCheck = CT + self.CollisionBoxCheckInterval

					-- TODO: Make this if-statement say only if static entity? Is that optimized? i.e. prevent this when bumping into moving zombies
					--if self.loco:GetVelocity():Length2D() <= 10 then
						local targetforward = self.loco:GetGroundMotionVector()

						local p = self:GetPos() + targetforward*boxcheckrange
						local tbl = ents.FindInBox(p+boxa,p+boxb)

						--debugoverlay.Box(p,boxa,boxb,1,Color(255,255,255,50))
						--debugoverlay.Line(self:GetPos(), p, 1, Color(0,0,255))
						--debugoverlay.Sphere(goal.pos, 5, 2, Color(255,0,0), true)

						for k,v in pairs(tbl) do
							if v.ZombieInteract then -- This only works for entities with ZombieInteract
								self.nzu_InteractTarget = v
								v:ZombieInteract(self, ent)

								if not self.ActiveEvent then
									self.nzu_InteractTarget = nil
									if v.ZombieInteractEnd then v:ZombieInteractEnd(self) end
								end
								return
							end
						end
					--end
				end

				-- In the end, call our own Interact function on the initial (potentially proxied) entity we collided with
				self:Interact(ent2)
			end

			-- Anti-stuck earlier! We can use this part of the function as it means we have collided with something that didn't trigger an event
			-- Since we haven't returned, we know we haven't found any other entity
			if not self.NextStuckCheck or self.NextStuckCheck < CT then
				if self.loco:IsAttemptingToMove() and self.loco:GetVelocity():LengthSqr() < 100 then -- sqrt(100) = 10
					if not self.AboutToBeStuck then
						self.AboutToBeStuck = CT + self.StuckDelay
					end
					if self.AboutToBeStuck <= CT then
						if not self:IsStuck() then self:OnStuck()end -- Become stuck, but only once
						self.CurrentlyStuckEntity = ent -- Update the stuck entity every time
						self.AboutToBeUnStuck = CT + self.UnStuckDelay
					end
				end

				self.NextStuckCheck = CT + self.StuckCheckInterval
			end
		end
	end

	function ENT:Timeout(time)
		self:PerformIdle()
		coroutine.wait(time)
	end

	function ENT:Freeze(time)
		if not self.FrozenThread then
			self.FrozenThread = self.BehaveThread
			self.BehaveThread = nil
		end
		self.FrozenTime = time and CurTime() + time or nil
	end

	function ENT:UnFreeze()
		if self.FrozenThread then
			self.BehaveThread = self.FrozenThread
			self.FrozenThread = nil
		end
		self.FrozenTime = nil
	end
	function ENT:IsFrozen() return self.FrozenThread and true or false end

	function ENT:FaceTowards(pos)
		self.loco:FaceTowards(pos)
		local ang = (pos - self:GetPos()):Angle()
		local ang2 = self:GetAngles()
		ang.p = ang2.p
		ang.r = ang2.r

		self:SetAngles(ang)
	end
end

--[[-------------------------------------------------------------------------
Events System
Attach custom handler functions to the Zombie's current behaviour
Each Zombie class may override the handler given they have an event of the same ID
Pass potential data as the third argument rather than directly in the handler
---------------------------------------------------------------------------]]
if SERVER then
	function ENT:TriggerEvent(id, data, handler)
		local func = self["Event_"..id] or handler
		if func then
			self.ActiveEvent = id
			self.EventHandler = func
			self.EventData = data

			if self.ActiveEvent and coroutine.running() then func(self, data) end -- Lapsing events
			return true
		end
		return false		
	end
	
	function ENT:RequestTerminateEvent()
		if self.ActiveEvent then
			self.Event_Terminate = true
		end
	end
	-- Build event handlers respecting this flag if possible
	function ENT:ShouldEventTerminate() return self.Event_Terminate end

	-- Run a sub-event. This should only be called inside coroutine (such as another event)
	function ENT:SubEvent(id, handler, data)
		local func = self["Event_"..id] or handler
		func(self, data)
	end

	-- Overwrite the bot's MoveToPos function
	-- Mostly copy/pasted from standard NextBot implementation but with added support for Event termination
	-- And using the bots own ComputePath function
	function ENT:MoveToPos(pos, options)
		local options = options or {}
		local path = Path("Follow")
		path:SetMinLookAheadDistance(options.lookahead or 300)
		path:SetGoalTolerance(options.tolerance or 20)
		path:Compute(self, pos, self.ComputePath)

		if not path:IsValid() then return "failed" end

		while path:IsValid() do
			if self.ActiveEvent and self:ShouldEventTerminate() then return "terminated" end

			path:Update(self)
			if options.draw then path:Draw() end
			if self:IsStuck() then
				self:HandleStuck()
				return "stuck"
			end
			if options.maxage then
				if path:GetAge() > options.maxage then return "timeout" end
			end
			if options.repath then
				if path:GetAge() > options.repath then path:Compute(self, pos, self.ComputePath) end
			end
			coroutine.yield()
		end
		return "ok"
	end
end

--[[-------------------------------------------------------------------------
Animations
---------------------------------------------------------------------------]]
function ENT:BodyUpdate()
	if not self.ActiveEvent then self:BodyMoveXY() else self:FrameAdvance() end
end

--[[-------------------------------------------------------------------------
Misc
---------------------------------------------------------------------------]]
if SERVER then
	-- Collide When Possible
	local collidedelay = 0.5
	local bloat = Vector(5,5,0)
	function ENT:Think()
		if self.DoCollideWhenPossible then
			if not self.NextCollideCheck or self.NextCollideCheck < CurTime() then
				local mins,maxs = self:GetCollisionBounds()
				local tr = util.TraceHull({
					start = self:GetPos(),
					endpos = self:GetPos(),
					filter = self,
					mask = MASK_NPCSOLID,
					mins = mins - bloat,
					maxs = maxs + bloat,
					ignoreworld = true
				})

				local b = IsValid(tr.Entity)
				if not b then
					self:SetSolidMask(MASK_NPCSOLID)
					self.DoCollideWhenPossible = nil
					self.NextCollideCheck = nil
					self.EventMask = nil
				else
					self.NextCollideCheck = CurTime() + collidedelay
				end
			end
		end
		if self.AboutToBeUnStuck and CurTime() >= self.AboutToBeUnStuck and CurTime() > self.NextStuckCheck then
			self:OnUnStuck()
		end

		if self.FrozenTime and CurTime() >= self.FrozenTime then
			self:UnFreeze()
		end
	end	
end

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Alive")
	self:DataTables()
end

if SERVER then
	function ENT:OnKilled(dmg)
		self:SetAlive(false)
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
		hook.Run("OnNPCKilled", self, dmg:GetAttacker(), dmg:GetInflictor())
		self:OnDeath(dmg)
		self:PerformDeath(dmg)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
		if self.RedEyes and self:Alive() then
			self:DrawEyeLight()
		end
	end

	local eyeglow = Material("sprites/redglow1")
	local white = color_white
	function ENT:DrawEyeLight()
		local latt,ratt = self:LookupAttachment("lefteye"), self:LookupAttachment("righteye")

		if latt < 1 then latt = self:LookupAttachment("left_eye") end
		if ratt < 1 then ratt = self:LookupAttachment("right_eye") end
		
		local righteyepos
		local lefteyepos
		if latt > 0 and ratt > 0 then
			local leye = self:GetAttachment(latt)
			local reye = self:GetAttachment(ratt)
			lefteyepos = leye.Pos + leye.Ang:Forward()*0.5
			righteyepos = reye.Pos + reye.Ang:Forward()*0.5
		else
			local eyes = self:GetAttachment(self:LookupAttachment("eyes"))
			if eyes then
				local right = eyes.Ang:Right()
				local forward = eyes.Ang:Forward()
				lefteyepos = eyes.Pos + right * -1.5 + forward * 0.5
				righteyepos = eyes.Pos + forward * 1.5 + forward * 0.5
			end
		end

		if lefteyepos and righteyepos then
			render.SetMaterial(eyeglow)
			render.DrawSprite(lefteyepos, 4, 4, white)
			render.DrawSprite(righteyepos, 4, 4, white)
		end
	end
end