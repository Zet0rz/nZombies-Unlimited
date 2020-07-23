--[[-------------------------------------------------------------------------
The Powerup Structure:
{
	Name = "Pretty Name",
	Model = "path/to/model.mdl",
	Color = Color,
	Scale = Number/nil,
	Material = String/nil,
	Duration = Number/nil,
	PlayerBased = true/nil,
	DefaultPersonal = true/nil,
	Undroppable = true/nil,
	Sound = Sound/nil,
	LoopSound = Sound/nil,
	Function = function(pos[, ply, neg]) end,
	EndFunction = function/nil,
}

Name: A display name. Only used if the HUD draws text rather than icons
Model: The model that the powerup drop has
Color: The color of the drop. This is in most cases gold (Color(255,255,100))
Scale: How big the model is. If nil, then this is just 1.
Material: If you want to override material, you can do it here. Nil means original model material.
Duration: The *DEFAULT* duration. Nil means the Powerup doesn't have a duration, but is instant
	Note: Powerups may be activated at different durations, this is the default duration.

PlayerBased: If true, then the function will get the 'ply' argument - The player who activated it
	It will also allow the powerup to exist in a "Personal" state. A global drop will then also
	loop through all players and call Function for each of them.

Negative: If true, the Powerup supports existing as Negative (red) with a bad effect. Will pass argument 'neg' to Function and EndFunction
	If both Negative and PlayerBased, will also support personal-negatives (purple) drops.
	Negatives do not naturally drop, but can be dropped from code.

DefaultPersonal: All drops can be global, and all PlayerBased can also be personal. If this is true,
	then this drop is by default Personal (but can still be spawned or activated global)

Undroppable: If set, this powerup cannot be enabled through settings to be part of the drop cycle. Instead, it can only
	be dropped by code. Example of this is Widows Wine drops, which always drop by code through the Perks system.

Sound: If set, will play this sound on activation, globally for all players
LoopSound: If set, will play this looping sound for the duration of the powerup. Only applies to those with Durations.
EndSound: If set, will play this sound when the Powerup ends. Only applicable to those with Durations.
	Note: If PlayerBased, then the above sounds are only played for players for which it activated (often all players)
	Note: If the powerup is negative, the above sounds will play at a lower pitch

Function: The function that runs when the powerup is activated. Will receive the position of the drop entity as argument and duration
	If PlayerBased is true, it will have a third argument: player, and the function will be called for all players individually

	Note: If PlayerBased and the drop was personal, this function only runs for that one player
		pos: The position the powerup was picked up from, if any (may be nil!)
		ply: Only passed if PlayerBased is true. The player for which this is activated
		neg: Only passed if Negative is true. This argument is true if the powerups is negative, false if positive

		Note: Arguments are in this order, but if one doesn't apply, the next will take its place. E.g.:
			PlayerBased+Negative = (pos, ply, neg)
			PlayerBased = (pos, ply)
			Negative = (pos, neg)
			None = (pos)

			etc...

	Note: This function only runs once when the Powerup is activated. If it is later re-activated to refresh
	the duration, this does not run the function again (but delays the EndFunction and extends PLAYER:PlayerHasPowerup)

EndFunction: The function that runs when the Powerup ends. Only automatically called for those with Durations.
	Receives 1 argument: Terminate - True when the effect was terminated prematurely (such as through the game resetting)
	All arguments following are identical to Function (based on set fields) except for 'pos' which isn't passed here

	Note: If Duration is not set but Function returns a duration, this function is called after that amount of time
		Subnote: This duration is private to the server, and Clients won't display or know about the time - it will remain instant for them
	Note: This function is prematurely called when the game ends or is reset, if it was about to be called
---------------------------------------------------------------------------]]

nzu.RegisterPowerup("MaxAmmo", {
	Name = "Max Ammo",
	Model = Model("models/nzu/powerups/maxammo.mdl"),
	Color = Color(255,255,100),
	--Duration is nil, this powerup is an instant activate
	PlayerBased = true, -- Max ammo is activated individually for players
	--Negative = true,
	Sound = Sound("nzu/powerups/maxammo/maxammo.wav"),
	Function = function(drop, ply, neg)
		if neg then
			-- Empty out the reserve ammo of their currently held weapon

		else
			ply:GiveMaxAmmo()
		end
	end,
})

nzu.RegisterPowerup("Carpenter", {
	Name = "Carpenter",
	Model = Model("models/nzu/powerups/carpenter.mdl"),
	Color = Color(255,255,100),
	-- Duration is nil, the drop is instant despite the effect happening over time
	-- Despite this, our Function returns a duration for the powerup to use internally
	Function = function(pos)
		local pos = pos or Vector()
		local barricades = ents.FindByClass("nzu_barricade") -- TODO: Some sort of subclass support?
		local max = 0
		for k,v in pairs(barricades) do
			local t = v:GetPos():Distance(pos)/2000 -- 1 second for every 2,000 units
			if t > max then
				max = t
			end
			timer.Simple(t, function()
				if IsValid(v) then
					v:FullRepair()
				end
			end)
		end

		return max -- We apply our own internal duration!
	end,
	LoopSound = Sound("nzu/powerups/carpenter/loop.wav"),
	EndSound = Sound("nzu/powerups/carpenter/end.wav"),
	EndFunction = function(terminate)
		if not terminate then
			for k,v in pairs(nzu.Round:GetPlayers()) do
				if not v:GetIsDowned() then
					v:GivePoints(200, "Carpenter")
				end
			end
		end
	end,
})

nzu.RegisterPowerup("Nuke", {
	Name = "Nuke",
	Model = Model("models/nzu/powerups/nuke.mdl"),
	Color = Color(255,255,100),
	Function = function(pos)
		local pos = pos or Vector()
		local zombs = ents.FindByClass("nzu_zombie") -- TODO: Also account for other entities
		local max = 0
		for k,v in pairs(zombs) do
			local t = v:GetPos():Distance(pos)/2000
			if t > max then
				max = t
			end

			v:SetBlockAttack(true) -- Can't attack!
			timer.Simple(t, function()
				if IsValid(v) then
					v:TakeDamage(v:Health(), nil, nil) -- DIE! >:D
					-- TODO: Make use of the upcoming BehaviorOverride death effects and use Nuke
					-- (also add the Soul sounds to that behavior event)
				end
			end)
		end

		return max -- We apply our own internal duration!
	end,
	LoopSound = Sound("nzu/powerups/carpenter/loop.wav"),
	EndSound = Sound("nzu/powerups/carpenter/end.wav"),
	EndFunction = function(terminate)
		if not terminate then
			for k,v in pairs(nzu.Round:GetPlayers()) do
				if not v:GetIsDowned() then
					v:GivePoints(400, "Nuke")
				end
			end
		end
	end,
})

nzu.RegisterPowerup("DoublePoints", {
	Name = "Double Points",
	Model = Model("models/nzu/powerups/doublepoints.mdl"),
	Color = Color(255,255,100),
	Duration = 30,
	PlayerBased = true,
	LoopSound = Sound("nzu/powerups/doublepoints/loop.wav"),
	EndSound = Sound("nzu/powerups/doublepoints/end.wav"),
	-- We don't do a function. Instead we have the hook below.
})

-- TODO: Add and remove this hook through Function and EndFunction to optimize?
hook.Add("nzu_PlayerGivePoints", "DoublePoints", function(ply, tbl, n)
	if ply:HasPowerup("DoublePoints") then -- Global = true for all players, personal = true only for that player (PlayerBased)
		tbl.Points = tbl.Points + n -- Just plus the original, disregarding other mods
	end
end)

nzu.RegisterPowerup("InstaKill", {
	Name = "Insta-Kill",
	Model = Model("models/nzu/powerups/instakill.mdl"),
	Color = Color(255,255,100),
	Duration = 30,
	PlayerBased = true, -- This is also player based. One player may have Instakill without another having
	LoopSound = Sound("nzu/powerups/instakill/loop.wav"),
	EndSound = Sound("nzu/powerups/instakill/end.wav"),
	-- Same as double points
})

hook.Add("EntityTakeDamage", "InstaKill", function(ent, dmg)
	local att = dmg:GetAttacker()
	if IsValid(att) and att:IsPlayer() and att:HasPowerup("InstaKill") then -- and ent:IsZombie() -- TODO: Add this function!
		dmg:SetDamage(ent:Health()) -- Instantly kill
	end
end)