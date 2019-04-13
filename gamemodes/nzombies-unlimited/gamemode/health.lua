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
else
	nzu.RegisterHUDComponentType("HUD_DamageOverlay")

	local overlay = Material("materials/overlay_low_health.png", "unlitgeneric smooth")
	local min_threshold = 0.7
	local max_threshold = 0.3
	local pulse_threshold = 0.4
	local pulse_time = 1
	local pulse_base = 0.75 -- How much of the full overlay is contributed by the base health (the rest is added by the pulse)

	nzu.RegisterHUDComponent("HUD_DamageOverlay", "Unlimited", {
		Paint = function()
			local ply = LocalPlayer() -- TODO: When spectating exists, replace this with view target
			local health = ply:Health()
			local max = ply:GetMaxHealth()

			local pct = health/max
			if pct < min_threshold then
				local fade = (pct < max_threshold and 1 or 1 - (pct - max_threshold)/(min_threshold - max_threshold))*pulse_base

				if pct < pulse_threshold then
					local pulse = 1 - (CurTime()%pulse_time)/pulse_time
					fade = fade + pulse*(1-pulse_base)
				end

				surface.SetMaterial(overlay)
				surface.SetDrawColor(255,0,0,255*fade)
				surface.DrawTexturedRect(0,0,ScrW(),ScrH())
			end
		end,
	})
end