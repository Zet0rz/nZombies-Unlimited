if SERVER then
	local regendelay = 4
	local regenhps = 200 -- Health per second after delay

	function GM:EntityTakeDamage(ent, dmg)
		if ent:IsPlayer() and not ent:GetIsDowned() then
			ent.nzu_RegenStart = CurTime() + regendelay
		end
	end

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
end