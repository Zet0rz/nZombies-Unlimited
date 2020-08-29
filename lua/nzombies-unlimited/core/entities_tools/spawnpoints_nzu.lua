local SPAWNER = {}
function SPAWNER:GetType()
	return self.Type
end

function SPAWNER:GetPos()
	return self.Pos
end
function SPAWNER:GetAngles()
	return self.Angles
end
function SPAWNER:GetQueue()
	return self.Queue
end

function SPAWNER:IsValid()
	return true -- Spawners are always valid, per-se
end

local queuetime = 2 -- How often to re-check for space to spawn a queued zombie
local function queuefunc(self)
	if CurTime() > self.NextQueue then
		local e = self.Queue[1]
		if self:HasSpace(e) then
			e:SetPos(self:GetPos())
			e:SetAngles(self:GetAngles()) -- Yes/no?
			e:Spawn()

			table.remove(self.Queue, 1)
		end

		if next(self.Queue) then
			self.NextQueue = CurTime() + queuetime
		else
			self.NextQueue = nil
			hook.Remove("Think", self)
		end
	end
end

-- Spawn a zombie. If it cannot spawn, it will be queued until there is space
-- The queue is in order of zombies being added to the queue
-- Pass noqueue to not add to the queue (only spawn if you can now)
function SPAWNER:Spawn(e, noqueue)
	if not self.Frozen and not self.NextQueue and self:HasSpace(e) then
		e:SetPos(self:GetPos())
		e:SetAngles(self:GetAngles()) -- Yes/no?
		e:Spawn()
		return true -- We could spawn!
	end

	if not noqueue then
		table.insert(self.Queue, e)
		if not self.NextQueue then
			self.NextQueue = CurTime() + queuetime
			hook.Add("Think", self, queuefunc)
		end
	end
	return false -- We couldn't spawn :/
end

function SPAWNER:HasSpace(ent)
	-- Optimization: No need to check trace in the same tick as another earlier check
	if self.LastSuccessfulCheck == engine.TickCount() then return true end

	local pos = self:GetPos() + Vector(0,0,1) -- TODO: Find a better solution than this :(
	local trace = {
		start = pos,
		endpos = pos,
		filter = ent,
		mask = MASK_NPCSOLID,
	}
	local result
	if IsValid(ent) then result = util.TraceEntity(trace, ent) else
		trace.mins = Vector(-20,-20,0)
		trace.maxs = Vector(20,20,70)
		result = util.TraceHull(trace)
	end
	
	if not result.Hit then
		self.LastSuccessfulCheck = engine.TickCount()
		return true
	end
	return false
end

function SPAWNER:HasQueue()
	return self.NextQueue and true or false
end

function SPAWNER:SetLockedWeight(w)
	self.LockedWeight = w
end
function SPAWNER:GetLockedWeight() return self.LockedWeight end

local getalltargetableplayers = nzu.GetAllTargetablePlayers
local softness = 2000
local cachetime = 2 -- Cache results for at least this long
function SPAWNER:CalculateWeight()
	if self.LockedWeight then return self.LockedWeight end

	local ct = CurTime()
	if self.NextWeightCalculation and ct < self.NextWeightCalculation then
		return self.Weight
	end

	local min = math.huge
	for k,v in pairs(getalltargetableplayers()) do
		local dist = self.Pos:Distance(v:GetPos())
		if dist < min then
			min = dist
		end
	end

	-- Wolfram this: plot y = 1 - (x*50)/((x*50)+2000) for x = 0..500 and y = 0..1
	-- Where x is the number of meters away from the closest player, and y is the weight
	-- (x*50 is roughly the conversion from Valve units to meters)
	local w = 1 - min/(min + softness)

	-- Cache results so that we don't recalculate multiple times too fast
	-- (Distance checks are expensive)
	self.Weight = w
	self.NextWeightCalculation = ct + cachetime
	return w
end

function SPAWNER:Freeze(b)
	self.Frozen = b

	if self.NextQueue then
		if b then hook.Remove("Think", self) else hook.Add("Think", self, queuefunc) end -- Update queue hooks
	end
end
function SPAWNER:IsFrozen() return self.Frozen end

function SPAWNER.__tostring(spawner)
	return "Spawner ["..spawner.Type.."]["..tostring(spawner.Pos).."]"
end
SPAWNER.__index = SPAWNER

local ENTITY = FindMetaTable("Entity")
local function NewSpawner(type, pos, ang)
	local Spawner = setmetatable({}, SPAWNER)
	Spawner.Pos = pos
	Spawner.Angles = ang
	Spawner.Type = type

	return Spawner
end

nzu.Spawns = nzu.Spawns or {}
local spawnpoints = nzu.Spawns
nzu.OpenSpawns = nzu.OpenSpawns or {}
local openspawns = nzu.OpenSpawns
function SPAWNER:Activate()
	if not self.Active then
		openspawns[self.Type][self] = true
		self.Active = true
	end
end

function SPAWNER:Deactivate()
	if self.Active then
		openspawns[self.Type][self] = nil
		self.Active = false
	end
end

nzu.AddSaveExtension("Spawnpoints", {
	-- Save and load aren't really needed here
	Load = function() end,
	PreLoad = function(tbl)
		nzu.Spawns = {}
		nzu.OpenSpawns = {}
		spawnpoints = nzu.Spawns
		openspawns = nzu.OpenSpawns

		for k,v in pairs(tbl) do
			if not spawnpoints[v.Type] then spawnpoints[v.Type] = {} end
			if not openspawns[v.Type] then openspawns[v.Type] = {} end

			local spawner = NewSpawner(v.Type, v.Pos, v.Ang)
			if v.Rooms and table.Count(v.Rooms) > 0 then
				spawner:SetRooms(v.Rooms)
			else
				spawner:Activate()
			end

			table.insert(spawnpoints[v.Type], spawner)
		end
	end
})

-- This is a cheeky way of enabling Entity-based Room system on non-entities (but it works fine, since they just need to be indexable - aka tables)
-- To make the hack work, we just have to ensure it doesn't error due to a lack of functions
SPAWNER.AddRoom = ENTITY.AddRoom
SPAWNER.SetRooms = ENTITY.SetRooms

-- Now we just add our opening function
function SPAWNER:OnRoomOpened(flag)
	self:Activate()
end

--[[-------------------------------------------------------------------------
Now getters and utility
---------------------------------------------------------------------------]]
function nzu.GetSpawners(type)
	return spawnpoints[type]
end

function nzu.GetActiveSpawners(type)
	return table.GetKeys(openspawns[type])
end

-- Utility for single-spawning at a random spawnpoint, chance based on its weight (calculated)
-- Since CalculateWeight caches, it's okay to repeat this multiple times in one tick
function nzu.PickWeightedRandomSpawner(type)
	local spawns = openspawns[type]
	local total = 0
	local possible = {}
	for k,v in pairs(spawns) do
		if not v:IsFrozen() then
			local w = v:CalculateWeight()
			total = total + w
			table.insert(possible, v)
		end
	end

	local ran = math.Rand(0, total)
	local cur = 0
	for k,v in pairs(possible) do
		cur = cur + v.Weight -- The cached result from before
		if cur >= ran then
			return v
		end
	end
end

-- Utility for multi-spawning a group. Returns a table with keys of all active spawners of that type
-- and values of their rounded distribution
function nzu.CalculateSpawnerDistribution(type, num)
	local spawns = openspawns[type]
	local total = 0
	local max = 0
	local top
	local possible = {}

	-- Get totals and the spawnpoint with highest weight
	for k,v in pairs(spawns) do
		if not v:IsFrozen() then
			local w = v:CalculateWeight()
			if w > max then
				max = w
				top = v
			end
			total = total + w
			table.insert(possible, v)
		end
	end

	if total <= 0 then
		return {} -- There's no spawnpoints with any weight :(
	end

	-- Distribute numbers over weight
	local tbl = {}
	local distributed = 0
	for k,v in pairs(possible) do
		local distr = math.Round(num * v.Weight/total)
		tbl[v] = distr
		distributed = distributed + distr
	end

	-- Subtract or add the leftovers from or to the highest weighted spawner
	-- i.e. we're still missing 1, give it to the highest weight
	-- OR we're 1 too much, remove 1 from the highest weight (that has the most)
	tbl[top] = tbl[top] + (num - distributed)
	return tbl
end