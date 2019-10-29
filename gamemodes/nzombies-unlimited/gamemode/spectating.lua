local PLAYER = FindMetaTable("Player")

local oldspec = PLAYER.SpectateEntity
function PLAYER:SpectateEntity(ent)
	oldspec(self, ent)
	if IsValid(ent) and ent:IsPlayer() then
		self:SetupHands(ent)
	end
end

local function canspec(ply, target)
	return target:Alive() and not target:IsUnspawned() or ply == target
end

function PLAYER:SpectateNext()
	local obs = self:GetObserverTarget()
	local foundcur = false
	local target

	for k,v in pairs(nzu.GetSpawnedPlayers()) do
		if canspec(self, v) then
			if foundcur then
				target = v
				break
			end

			if not target then target = v end
			if not IsValid(obs) or obs == v then
				foundcur = true
			end
		end
	end

	if IsValid(target) then
		self:SpectateEntity(target)
		if target ~= self then
			if self:GetObserverMode() == OBS_MODE_NONE then self:SetObserverMode(OBS_MODE_IN_EYE) end
			return
		end
	end
	self:SetObserverMode(OBS_MODE_NONE)
end

function PLAYER:SpectatePrevious()
	local obs = self:GetObserverTarget()
	local target

	for k,v in pairs(nzu.GetSpawnedPlayers()) do
		if canspec(self, v) then
			if obs == v and target then
				break
			end
			target = v
		end
	end

	if IsValid(target) then
		self:SpectateEntity(target)
		if target ~= self then
			if self:GetObserverMode() == OBS_MODE_NONE then self:SetObserverMode(OBS_MODE_IN_EYE) end
			return
		end
	end
	self:SetObserverMode(OBS_MODE_NONE)
end
	

function GM:PlayerDeathThink(ply)
	if ply.nzu_SpectateTime then
		if CurTime() >= ply.nzu_SpectateTime then
			ply:SetObserverMode(OBS_MODE_IN_EYE)
			ply:SpectateNext()
			ply.nzu_SpectateTime = nil
		end
		return
	end

	if not ply:IsUnspawned() then
		if ply:KeyPressed(IN_ATTACK) then
			ply:SpectateNext()
		elseif ply:KeyPressed(IN_ATTACK2) then
			ply:SpectatePrevious()
		end
	end
end

hook.Add("PostPlayerDeath", "nzu_Spectating_PostDeathSpectate", function(ply)
	ply.nzu_SpectateTime = CurTime() + 5
end)

local function unspec(ply)
	if ply.nzu_SpectateTime then
		ply.nzu_SpectateTime = nil
		-- Do more?
	end
	if ply:GetObserverMode() ~= OBS_MODE_NONE then
		ply:UnSpectate()
	end
end
hook.Add("PlayerSpawn", "nzu_Spectating_RemoveSpectate", unspec)
hook.Add("nzu_PlayerUnspawned", "nzu_Spectating_RemoveSpectate", unspec)