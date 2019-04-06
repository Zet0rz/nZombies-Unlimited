AddCSLuaFile()

print("LOADING HERE!")

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
-- Callable: Functions you can call, but really shouldn't overwrite
-- Overridables: These can be overridden to make your own implementation and are called internally by the base. They all have a default (as seen here).
--------------

--[[-------------------------------------------------------------------------
Localization/optimization
---------------------------------------------------------------------------]]
local nzu = nzu
local getalltargetableplayers = nzu.GetAllTargetablePlayers
local CurTime = CurTime

local function validtarget(ent)
	return IsValid(ent) and ent:IsTargetable()
end

local coroutine = coroutine

--[[-------------------------------------------------------------------------
Initialization
---------------------------------------------------------------------------]]
if SERVER then
	------- Overridables -------

	-- Lets you determine what class of model this zombie is, along with a default
	-- if it cannot be chosen by the gamemode's Model Packs settings
	function ENT:SelectModel()
		return "ZombieModels", "models/nzu/nzombie_honorguard.mdl"
	end

	-- Called after each event to determine its base movement animation
	-- This could be dependant on the zombie's movement speed
	-- It is called whenever an event is done and the zombie returns to normal movement
	function ENT:SelectMovementSequence()
		return self.MovementSequence
	end

	-- Called by the round when the Zombie spawns
	-- It is given the curve-based speed from Round as an argument
	-- but it can manage its own modifications if needed
	function ENT:SelectMovementSpeed(speed)
		return 100
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

--[[-------------------------------------------------------------------------
Targeting
---------------------------------------------------------------------------]]
if SERVER then
	------- Callables -------
	function ENT:GetTarget() return self.Target end -- Get the current target
	function ENT:SetTarget(t) if self:AcceptTarget(t) then self.Target = t end end -- Sets the target for the next path update
	function ENT:SetTargetLocked(b) self.TargetLocked = b end -- Stops the Zombie from retargetting and keeps this target while it is valid and targetable
	function ENT:SetNextRetarget(time) self.NextRetarget = CurTime() + time end -- Sets the next time the Zombie will repath to its target
	function ENT:Retarget() -- Causes a retarget
		if self.TargetLocked and validtarget(self.Target) then return end

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
	-- This is called after the path is computed; NOT after retarget
	function ENT:CalculateNextRetarget(target, dist)
		return 5
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
	------- Callables -------
	function ENT:ForceRepath() self.NextRepath = 0 end -- Forces the Zombie to recompute its path next tick
	function ENT:SetNextRepath(time) self.NextRepath = time end -- Sets how long until the next time the bot will repath. Relative to current path's age

	function ENT:LockTargetPosition(pos) self.LockedTargetPosition = pos end -- Lock to a new target location, rather than self.Target's location
	function ENT:GetTargetPosition() return self.LockedTargetPosition or self:SelectTargetPosition() end -- Get the current goal location. Supports locked goal locations
	function ENT:GetLockedTargetPosition() return self.LockedTargetPosition end -- Gets whether there is a locked target location or not (and which if so)

	function ENT:TerminatePath() self.Path = nil end -- Forces the Zombie to re-initialize its pathing. You shouldn't have to ever call this

	-- Returns to normal movement sequence. Call this in events where you want to MoveToPos after an animation
	function ENT:ResetMovementSequence()
		local seq = self:SelectMovementSequence()
		self:ResetSequence(seq)
	end

	-- Returns whether the current path goal exists and it is in the same 180-degree direction as the argument position
	function ENT:IsMovingTowards(pos)
		return self.Path and (pos - self:GetPos()):Dot(self.Path:GetCurrentGoal().forward) > 0
	end

	------- Overridables -------
	-- function ENT.ComputePath() end -- This is commented out as the default is 'nil' (default path generator)

	-- Called after a repath. This lets you determine how long before the bath should be recomputed
	-- It is a good optimization idea to base this off of the prior path's length
	function ENT:CalculateNextRepath()
		return 2
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
	ENT.AttackDamage = 30
	ENT.AttackRange = 60

	-- List of different attack sequences, and the cycle at which they impact
	-- Impacts are in cycle (0-1), the percentage through the sequence
	-- It may contain multiple entries, at which point the Zombie will hit multiple times
	-- They must be sequential.
	-- These are also used for ENT:DoAttackFunction(), only first if 'multihit' is not true
	ENT.AttackSequences = {
		{Sequence = "swing", Impacts = {0.5}}
	}

	------- Callables -------

	-- Perform an attack
	-- It selects an attack animation and plays it, dealing damage during its moments of impact
	-- A damage info can be passed, otherwise a default is created
	function ENT:AttackTarget(target, dmg)
		if IsValid(target) then
			local dmg = dmg
			if not dmg then
				dmg = DamageInfo()
				dmg:SetDamage(self.AttackDamage)
				dmg:SetDamageType(DMG_SLASH)
				dmg:SetAttacker(self)
				--dmg:SetDamageForce()
			end

			-- Perform the attack with the function of hurting the target!
			self:DoAttackFunction(target, function(self, target)
				if self:GetRangeTo(target) <= self.AttackRange then target:TakeDamageInfo(dmg) end
			end, true)
		end
	end

	-- Plays an attack animation and at the moment of impact, executes the function
	-- This should only be called in an event handler (or otherwise in the bot's coroutine)
	function ENT:DoAttackFunction(target, func, multihit, speed)
		speed = speed or 1

		local attack = self:SelectAttack(target)
		self:FaceTowards(target:GetPos())

		local seqdur = self:SetSequence(attack.Sequence)/speed
		self:ResetSequenceInfo()
		self:SetCycle(0)
		self:SetPlaybackRate(speed)

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

	------- Overridables -------

	-- Select which attack sequence table to use for an upcoming attack
	-- This can be dependant on the target, but could also be anything
	-- We just pick a random in the AttackSequences table here
	function ENT:SelectAttack(target)
		return self.AttackSequences[math.random(#self.AttackSequences)]
	end
end

--[[-------------------------------------------------------------------------
Vaults
Similar to attacks, these are just fields along with a SelectVault function
---------------------------------------------------------------------------]]
if SERVER then
	------- Fields -------
	ENT.VaultSequence = "nz_barricade_walk_1" -- What animation to vault with
	ENT.VaultSpeed = 50 -- How fast the zombie moves over the vault

	------- Overridables -------

	-- Select a vault sequence based on the target location
	function ENT:SelectVaultSequence(pos)
		return self.VaultSequence, self.VaultSpeed
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
	function ENT:SolidMaskDuringEvent(mask) self:SetSolidMask(mask) self.EventMask = true end -- The zombie will not collide with other zombies for the duration of the current event

	function ENT:CollideWhenPossible() self.DoCollideWhenPossible = true end -- Make the zombie solid again as soon as there is space

	------- Basic Events -------

	-- Play a basic spawn animation before moving on
	function ENT:Event_Spawn()
		if self.SpawnSequence then
			self:PlaySequenceAndWait(self.SpawnSequence)
		end
	end

	-- Perform a basic attack on the given target
	function ENT:Event_Attack(target)
		self:AttackTarget(target or self.Target)
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

		if self.Path and (to - self:GetPos()):Dot(self.Path:GetCurrentGoal().forward) < 0 then return end -- Don't vault at all if the direction of vault is away from where we want to go

		local stucktime

		-- If from exists, move to that position first
		if from then
			local path = Path("Follow")
			path:SetGoalTolerance(20)
			path:Compute(self, from, self.ComputePath)
			if not path:IsValid() then return end

			while path:IsValid() do
				if self:ShouldEventTerminate() then return end -- We support terminating the event only before the vault

				path:Update(self)
				if self.loco:IsStuck() then
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
		end
		stucktime = nil

		local name,groundspeed = self:SelectVaultSequence(to)
		local seq,dur = self:LookupSequence(name)

		-- Get a path to the target location so we can get the distance
		local path = Path("Follow")
		path:SetGoalTolerance(20)
		path:Compute(self, to, self.ComputePath)
		if not path:IsValid() then return end

		local dist = path:GetLength()
		self:ResetSequence(seq)
		self:SetCycle(0)
		local rate = dur/(dist/groundspeed)
		self:SetPlaybackRate(rate)
		self.loco:SetDesiredSpeed(dist/dur)

		self:SetSolidMask(MASK_NPCWORLDSTATIC) -- Nocollide with props and other entities (we remove this with CollideWhenPossible)

		while path:IsValid() do
			path:Update(self)

			if self.loco:IsStuck() then
				if not stucktime then
					stucktime = CurTime() + 2
					self:SetPlaybackRate(0)
				elseif stucktime < CurTime() then
					self:SetPos(to) -- Give up and teleport
					return
				end
			elseif stucktime then -- Resume the vault
				stucktime = nil
				self:SetPlaybackRate(rate)
			end
			coroutine.yield()
		end

		self.loco:SetDesiredSpeed(self.DesiredSpeed)
		self:CollideWhenPossible() -- Remove the mask as soon as we can
	end
end

--[[-------------------------------------------------------------------------
AI
A stack of functions that are called from the bot's RunBehaviour
These let you modify the bot's AI and behavior completely
---------------------------------------------------------------------------]]
if SERVER then
	------- Overridables -------

	-- Called when the zombie is stuck
	function ENT:OnStuck()
		self:Respawn()
	end

	-- When a path ends. Either when the goal is reached, or when no path could be found
	-- This is where you should trigger your attack event or idle
	function ENT:OnPathEnd()
		print(self, self.Target, self.PreventAttack)
		if IsValid(self.Target) and not self.PreventAttack then
			self:TriggerEvent("Attack", self.Target)
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
		path:SetGoalTolerance(self.AttackRange)

		path:Compute(self, self:GetTargetPosition(), self.ComputePath)
		self:SetNextRepath(self:CalculateNextRepath(path))
		self:ResetMovementSequence()
	end

	-- Called while a path is valid and right after the bot has moved along the path
	-- Lets you do things such as decide to randomly stop or change targets and recompute
	-- Note: This is called in every loop - use some delay measure to not spam expensive functions
	-- Default: Do nothing (just move along the path)
	function ENT:AI()

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
	function ENT:PerformIdle()
		--PrintTable(self:GetSequenceList())
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
		local m,fallback = self:SelectModel()
		self:SetModel(fallback)

		self:SetNextRepath(0)
		self:SetNextRetarget(0)
	end

	self:Init()
	self:OnSpawn()
end

if SERVER then
	function ENT:SetDesiredSpeed(speed)
		self.DesiredSpeed = self:SelectMovementSpeed(speed)
		self.loco:SetDesiredSpeed(self.DesiredSpeed)
	end

	function ENT:RunBehaviour()
		while true do
			if self.ActiveEvent then
				self:EventHandler(self.EventData) -- This handler should be holding the routine until it is done

				self.ActiveEvent = nil
				self.EventData = nil

				if self.EventMask then
					self:SetSolidMask(MASK_NPCSOLID)
					self.EventMask = nil
				end

				local interacting = self.nzu_InteractTarget
				if IsValid(interacting) then
					if interacting.ZombieInteractEnd then interacting:ZombieInteractEnd(self) end
					self.nzu_InteractTarget = nil -- Remove the proxy if any
				end

				if IsValid(self.Path) then self:ResetMovementSequence() end
			end

			local ct = CurTime()
			if ct >= self.NextRetarget then
				self:Retarget()
			end

			if not IsValid(self.Target) then
				self:OnNoTarget()
			else
				local path = self.Path
				if not path then
					self:InitializePath()
				elseif not IsValid(path) then -- We reached the goal, or path terminated for another reason
					self:OnPathEnd()
					self.Path = nil

					if not IsValid(self.Target) or not self:AcceptTarget(self.Target) then
						self:SetNextRetarget(0) -- Always retarget at the end of a path if the current target no longer exists or is not acceptable anymore (such as downed)
					end
				else
					-- DEBUG
					path:Draw()

					if path:GetAge() >= self.NextRepath then
						if not IsValid(self.Target) then
							self:SetNextRetarget(0) -- Retarget next cycle
							coroutine.yield()
							continue
						end
						path:Compute(self, self:GetTargetPosition(), self.ComputePath)
						self:SetNextRepath(self:CalculateNextRepath())
					end
					path:Update(self)

					self:AI()
				end
			end

			coroutine.yield()
		end
	end

	function ENT:OnContact(ent)
		if not self.ActiveEvent and IsValid(ent) then
			local ent2 = ent
			if ent.nzu_InteractTarget then ent2 = ent.nzu_InteractTarget else ent2 = ent end -- Bumping into a proxy interactor

			if IsValid(ent2) and ent2.ZombieInteract then
				self.nzu_InteractTarget = ent2 -- Turn ourselves into a proxy for the duration of the interaction
				ent2:ZombieInteract(self, ent)

				-- Remove our proxy only if the interaction did not cause an event
				-- Otherwise, the end of the event will remove the proxy
				if not self.ActiveEvent then
					self.nzu_InteractTarget = nil
					if ent2.ZombieInteractEnd then ent2:ZombieInteractEnd(self) end
				end
			end
		end
	end

	function ENT:Timeout(time)
		self:PerformIdle()
		coroutine.wait(time)
	end

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
	function ENT:TriggerEvent(id, handler, data)
		if self.ActiveEvent then return end
		
		local func = self["Event_"..id] or handler
		if func then
			self.ActiveEvent = id
			self.EventHandler = func
			self.EventData = data
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
			if self.loco:IsStuck() then
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
			else
				self.NextCollideCheck = CurTime() + collidedelay
			end
		end
	end
end