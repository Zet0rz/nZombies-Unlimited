local PLAYER = FindMetaTable("Player")

-- Optimize
local next = next

function PLAYER:IsTargetable()
	-- Has an untargetability table and it's non-empty
	return not self.nzu_Untargetability
end

function PLAYER:AddUntargetability(id)
	if not self.nzu_Untargetability then self.nzu_Untargetability = {} end
	self.nzu_Untargetability[id] = true
end

function PLAYER:RemoveUntargetability(id)
	if self.nzu_Untargetability then
		self.nzu_Untargetability[id] = nil

		if next(self.nzu_Untargetability) == nil then self.nzu_Untargetability = nil end
	end
end

hook.Add("PostPlayerDeath", "nzu_Targeting_PlayerResetTargetability", function(ply) ply.nzu_Untargetability = nil end)

local round = nzu.Round
function nzu.GetAllTargetablePlayers()
	local t = {}
	for k,v in pairs(round:GetPlayers()) do
		if v:Alive() and v:IsTargetable() then
			table.insert(t,v)
		end
	end
	return t
end

local ENTITY = FindMetaTable("Entity")
function ENTITY:SetTargetable(b)
	self.nzu_Targetable = b
end

function ENTITY:IsTargetable()
	return self.nzu_Targetable
end