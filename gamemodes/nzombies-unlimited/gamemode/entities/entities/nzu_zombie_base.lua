AddCSLuaFile()

print("LOADING HERE!")

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.Category = "nZombies Unlimited"
ENT.Author = "Zet0r"
ENT.Spawnable = true

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

--[[-------------------------------------------------------------------------
Initialization
---------------------------------------------------------------------------]]

------- Overridables -------

-- Lets you determine what class of model this zombie is, along with a default
-- if it cannot be chosen by the gamemode's Model Packs settings
function ENT:SelectModel()
	return "zombie", "models/nzombies/nzombie_honorguard.mdl"
end

-- Called after each event to determine its base movement animation
-- This should be dependent on the zombie's speed
-- It can be cached in the OnSpawn or in the
function ENT:SelectMovementSequence()
	return "nz_walk_ad1"
end

-- Called by the round when the Zombie spawns
-- It is given the curve-based speed from Round as an argument
-- but it can manage its own modifications if needed
function ENT:SelectMovementSpeed(speed)
	return 100
end

-- Called as the zombie spawns before it starts its Spawning event
-- Also called on respawns, so it's not always on initial creation!
function ENT:OnSpawn() end

--[[-------------------------------------------------------------------------
Targeting
---------------------------------------------------------------------------]]

------- Callables -------
function ENT:GetTarget() return self.Target end -- Get the current target
function ENT:SetTarget(t) if self:AcceptTarget(t) then self.Target = t end end -- Sets the target for the next path update
function ENT:SetTargetLocked(b) self.TargetLocked = b end -- Stops the Zombie from retargetting and keeps this target while it is valid and targetable
function ENT:SetNextRetarget(time) self.NextRetarget = CurTime() + time end -- Sets the next time the Zombie will repath to its target
function ENT:Retarget() -- Causes a retarget
	if self.TargetLocked and validtarget(ent) then return end
	self.Target = self:SelectTarget()
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
function ENT:CalculateNextRetarget(dist)
	return 5
end

--[[-------------------------------------------------------------------------
Pathing
---------------------------------------------------------------------------]]

------- Callables -------
function ENT:ForceRepath() self.NextRepath = 0 end -- Forces the Zombie to recompute its path next tick
function ENT:SetNextRepath(time) self.NextRepath = time end -- Sets how long until the next time the bot will repath. Relative to current path's age

------- Overridables -------
-- function ENT.ComputePath() end -- This is commented out as the default is 'nil' (default path generator)

function ENT:OnStuck() -- Called when the zombie is stuck
	self:Respawn()
end

-- Called after a repath. This lets you determine how long before the bath should be recomputed
-- It is a good optimization idea to base this off of the prior path's length
function ENT:CalculateNextRepath()
	return 2
end

-- When a path ends. Either when the goal is reached, or when no path could be found
-- This is where you should trigger your attack event or idle
function ENT:OnPathEnd()
	if IsValid(self.Target) and not self.PreventAttack then
		self:TriggerEvent("Attack", self.Target)
	else
		self:Timeout(2)
	end
end

--[[-------------------------------------------------------------------------
Attacking
---------------------------------------------------------------------------]]

------- Callables -------

function ENT:AttackTarget(target) -- Deal damage to its target if within range
	if IsValid(target) and self:GetRangeTo(target) <= self.AttackRange then
		local dmg = DamageInfo()
		dmg:SetAttacker(self)
		dmg:SetDamage(self.Damage)
		dmg:SetDamageType(DMG_SLASH)
		--dmg:SetDamageForce()

		target:TakeDamageInfo(dmg)
	end
end

--[[-------------------------------------------------------------------------
Events
---------------------------------------------------------------------------]]

------- Callables -------
function ENT:GetCurrentEvent() return self.ActiveEvent end -- Returns the string ID of the currently played event, if any

------- Overridables -------
ENT.Events = {} -- A table of events that this zombie supports
ENT.Events.Spawn = {
	Sequence = "nz_spawn_climbout_fast"
}

ENT.Events.Attack = {
	{
		Sequence = "nz_attack_walk_ad_1",
		Events = {
			{Cycle = 0.2, Function = function(self, target) self:AttackTarget(target) end}
		}
	}
}

-- Gets the Event Table from an ID. This can be used to randomly pick
-- or to parse values based on other factors such as movement speed
-- It can also generate events if need to be
-- If it returns nil, the event triggered will use the caller's fallback (if any)
function ENT:GetEvent(id)
	local event = self.Events[id]
	if event[1] then return event[math.random(#event)] -- Pick a random if a subtable
	return event
end

--[[-------------------------------------------------------------------------
Core
Below here is the base code that you shouldn't override
(but you still can if you really want to)
---------------------------------------------------------------------------]]
function ENT:Initialize()
	local m,fallback = self:SelectModel()
	self:SetModel(fallback)

	self.Path = Path("Chase")
	self.Path:SetMinLookAheadDistance(200)
	self.Path:SetGoalTolerance(32)

	self:SetNextPathUpdate(0)
	self:SetNextRetarget(0)

	self:TriggerEvent("Spawn")
end

function ENT:RunBehaviour()
	while true do
		if self.ActiveEvent then
			if self.Event_Start then self:Event_Start(self.Event_Data) self.Event_Start = nil end

			local cycle = self:GetCycle()

			local c = self.Event_Cycle
			if c and cycle >= c then
				self:Event_Function(self.Event_Data)

				local i = self.Event_Index + 1
				local nextup = self.Event_Events[i]
				if nextup then
					self.Event_Index = i
					self.Event_Cycle = nextup.Cycle
					self.Event_Function = nextup.Function
				else
					self.Event_Cycle = nil -- This stops the check
					self.Event_Function = nil
					self.Event_Events = nil
					self.Event_Index = nil
				end
			end

			if self.Event_Handle then self:Event_Handle(self.Event_Data) end

			if cycle >= 1 then
				if not self.Event_Loopback or self:Event_Loopback(self.Event_Data) then
					self:EndEvent()
				end
			end
		else
			local ct = CurTime()
			if ct >= self.NextRetarget then
				self.Target, dist = self:SelectTarget()
				self:SetNextRetarget(self:CalculateNextRetarget(dist))
			end

			local path = self.Path
			if self.EventEnded then -- After an event has ended, do a repath if needed
				if not path:IsValid() then
					path:Compute(self, self.Target:GetPos(), self.ComputePath)
					self:SetNextRepath(self:CalculateNextRepath())
				end
				self.EventEnded = nil
				self:SetSequence(self:SelectMovementSequence())
			end

			if not path:IsValid() then -- We reached the goal, or path terminated for another reason
				self:OnPathEnd()
			else
				if path:GetAge() >= self.NextRepath then
					path:Compute(self, self.Target:GetPos(), self.ComputePath)
					self:SetNextRepath(self:CalculateNextRepath())
				end
				path:Chase(self)
			end
		end
	end
end

function ENT:Timeout(time)
	coroutine.wait(time)
end

--[[-------------------------------------------------------------------------
Events System
Run specific sequences on specific events			(All fields are optional)
Events are tables that may contain:
	- Sequence: A string of the sequence to play (first)
	- Start: A function that runs at the start of the event.
		> This function is called with argument given in self:TriggerEvent after the id
	- Events: A subtable containing tables of format:
		- Cycle: The cycle at which the below function will trigger (0-1)
		- Function: The function to trigger at this cycle key point
	- Loopback: A function which is run at the end of each Event loop.
		If this exists, the Event will not end by itself with the sequence
		Rather, this function is required to return true to end the loop event
		> This function is called with argument given in self:TriggerEvent after the id
	- Handle: A function that is run at every behaviour tick
		> This function is called with argument given in self:TriggerEvent after the id
---------------------------------------------------------------------------]]
function ENT:TriggerEvent(id, data, fallback)
	if self.ActiveEvent then
		self:EndEvent()
	end

	local event = self:GetEvent(id) or fallback
	if event then
		self.ActiveEvent = id
		if event.Sequence then self:ResetSequence(event.Sequence) end

		if event.Events then
			self.Event_Index = 1
			self.Event_Events = event.Events
			self.Event_Cycle = event.Events[1].Cycle
			self.Event_Function = event.Events[1].Function
		else
			self.Event_Cycle = nil
			self.Event_Function = nil
			self.Event_Events = nil
			self.Event_Index = nil
		end

		self.Event_Start = event.Start
		self.Event_Loopback = event.Loopback
		self.Event_Handle = event.Handle
		self.Event_Data = data
	end
end

function ENT:EndEvent()
	self.ActiveEvent = nil
	self.Event_Data = nil
	self.EventEnded = true
	-- The Zombie will automatically kill the animation next tick in its behavior
end