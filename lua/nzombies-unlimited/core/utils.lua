
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