local regendelay = 4
local regenhps = 200 -- Health per second after delay

function GM:EntityTakeDamage(ent, dmg)
	if ent:IsPlayer() then
		if not ent:GetIsDowned() then
			if dmg:GetDamage() >= ent:Health() then
				ent:DownPlayer()
				return true
			else
				ent.nzu_RegenStart = CurTime() + regendelay
			end
		else
			-- Downed player, block any damage
			return true
		end
	end

	local dpos = dmg:GetDamagePosition()
	local dpos2
	local att = dmg:GetAttacker()
	if att then
		if att.GetAimVector then
			dpos2 = dpos + att:GetAimVector()*100
		elseif att.GetShootPos then
			dpos2 = dpos + (dpos - att:GetShootPos())
		else
			dpos2 = dpos + (dpos - att:GetPos())
		end
	else
		dpos2 = ent:GetPos()
	end
	local trace = util.TraceLine({
		start = dpos,
		endpos = dpos2,
		mask = MASK_SHOT,
	})
	-- Scale headshot damage!
	if trace.HitGroup == HITGROUP_HEAD then
		dmg:ScaleDamage(4)
	end
	hook.Run("PostEntityTakeDamage", ent, dmg, trace.HitGroup or HITGROUP_GENERIC)
end

hook.Add("PlayerShouldTakeDamage", "nzu_Health_NoFriendlyFire", function(ply, att)
	if att:IsPlayer() and att ~= ply then return false end
end)

hook.Add("PlayerPostThink", "nzu_Health_PlayerRegen", function(ply)
	if ply.nzu_RegenStart and CurTime() > ply.nzu_RegenStart then
		local targethealth = ply:Health() + regenhps*FrameTime()
		if targethealth >= ply:GetMaxHealth() then
			targethealth = ply:GetMaxHealth()
			ply.nzu_RegenStart = nil -- Stop regenning after reaching max health
		end
		ply:SetHealth(targethealth)
	end
end)

-- This doesn't actually apply to Nextbots, but if anyone decides to use NPCs, we don't do damage scaling as that is done in GM:EntityTakeDamage
function GM:ScaleNPCDamage(npc, hitgroup, dmginfo) end

-- We don't do any killfeedin'
function GM:OnNPCKilled() end