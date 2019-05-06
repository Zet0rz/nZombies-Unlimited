
-- Weighted Random, using binary search for O(log n) complexity
-- Keys are items, values are their chance
function nzu.WeightedRandom(tbl)
	local total = 0
	local num = 0
	local vals = {}
	for k,v in pairs(tbl) do
		local pre = total
		total = total + v
		num = num + 1
		vals[num] = {k,total}
	end

	local ran = math.random(total)
	num = math.ceil(num/2)
	local marker = num
	while true do
		if vals[marker][2] >= ran then
			if num == 1 then
				return vals[marker][1]
			else
				num = math.ceil(num/2)
				marker = marker - num
			end
		else
			num = math.ceil(num/2)
			marker = marker + num
		end
	end
end

-- Queued net read entity functions. Read the ID of the entity and queue a function that runs as soon as the Entity becomes valid
local function setfunc(t,f) t.Function = f end
local queue
local function doqueue(ent)
	if queue[ent:EntIndex()] then
		for k,v in pairs(queue[ent:EntIndex()]) do
			v.Function(ent)
		end
		queue[ent:EntIndex()] = nil
		if not next(queue) then
			queue = nil
			hook.Remove("OnEntityCreated", "nzu_Util_NetReadEntityQueued")
		end
	end
end

function net.ReadEntityQueued()
	local i = net.ReadUInt(16)
	local ent = Entity(i)
	if IsValid(ent) then
		return ent
	end

	if not queue then
		queue = {}
		hook.Add("OnEntityCreated", "nzu_Util_NetReadEntityQueued", doqueue)
	end

	local t = {Run = setfunc}
	if not queue[i] then queue[i] = {} end
	table.insert(queue[i], t)
	return t
end