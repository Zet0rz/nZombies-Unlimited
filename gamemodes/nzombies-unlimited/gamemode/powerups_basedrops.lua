--[[-------------------------------------------------------------------------
The Powerup Structure:
{
	Name = "Pretty Name",
	Model = "path/to/model.mdl",
	Color = Color,
	Scale = Number/nil,
	Material = String/nil,
	Duration = Number/nil,
	Global = true/nil,
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

Global: If true, the powerup will not be able to be spawned in a "Personal" state.
	Additionally, the Function is only run once, and "ply" is not passed
	Without Global, the Function will run through each playing player, as well as when new players drop in
	while the effect is active

Negative: If true, the Powerup supports existing as Negative (red) with a bad effect. Will pass argument 'neg' to Function and EndFunction
	If both Negative and PlayerBased, will also support personal-negatives (purple) drops.
	Negatives do not naturally drop, but can be dropped from code.

DefaultPersonal: If this is true, then this drop is by default Personal (but can still be spawned or activated global)
	This does not work if the powerup is Global, as Personal state does not exist

Undroppable: If set, this powerup cannot be enabled through settings to be part of the drop cycle. Instead, it can only
	be dropped by code. Example of this is Widows Wine drops, which always drop by code through the Perks system.

Sound: If set, will play this sound on activation, globally for all players
LoopSound: If set, will play this looping sound for the duration of the powerup. Only applies to those with Durations.
EndSound: If set, will play this sound when the Powerup ends. Only applicable to those with Durations.
	Note: If PlayerBased, then the above sounds are only played for players for which it activated (often all players)
	Note: If the powerup is negative, the above sounds will play at a lower pitch

Function: The function that runs when the powerup is activated. It will loop through all players who are currently playing on which it applies
	If Global is true, this Function will only run ONCE, and will NOT receive any players.

	Arguments:
		pos: The position the powerup was picked up from, if any (may be nil!)
		neg: This argument is true if the powerups is negative, false if positive
		dur: The duration of the effect. Is nil if the powerup doesn't have Duration set.
		ply: The player for which this is activated. Will not be passed if Global is true.

	Note: This function only runs once when the Powerup is activated. If it is later re-activated to refresh
	the duration, this does not run the function again (but delays the EndFunction and extends PLAYER:PlayerHasPowerup)

	Note: If the powerup does not have a Duration, but this function returns a number, this will be networked to clients
	and the LoopSound will run for this duration. (Only Server-side this return is used)

EndFunction: The function that runs when the Powerup ends. Only automatically called for those with Durations.
	Arguments:
		neg: This argument is true if the powerup is negative, false if positive
		ply: The player for which this ends. Is nil if the powerup is Global.
		terminate: True if the powerup was terminated (ended prematurely, such as by Game Over, player dropping out, or nzu.TerminatePowerup)

	Note: This function is prematurely called when the game ends or is reset, and for non-Globals for each player when they drop out, if the powerup was active for them.
	Terminate will be true in this case
---------------------------------------------------------------------------]]

nzu.RegisterPowerup("MaxAmmo", {
	Name = "Max Ammo",
	Model = Model("models/nzu/powerups/maxammo.mdl"),
	Color = Color(255,255,100),
	--Duration is nil, this powerup is an instant activate
	--Negative = true,
	Sound = Sound("nzu/powerups/maxammo/maxammo.wav"),
	Function = SERVER and function(pos, neg, dur, ply)
		if neg then
			-- Empty out the reserve ammo of their currently held weapon

		else
			ply:GiveMaxAmmo()
		end
	end or nil,
})

nzu.RegisterPowerup("Carpenter", {
	Name = "Carpenter",
	Model = Model("models/nzu/powerups/carpenter.mdl"),
	Color = Color(255,255,100),
	-- Duration is nil, the drop is instant despite the effect happening over time
	-- Despite this, our Function returns a duration for the powerup to use internally
	Global = true,
	--Negative = true,
	Function = SERVER and function(pos)
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

		timer.Simple(max, function()
			for k,v in pairs(nzu.Round:GetPlayers()) do
				if not v:GetIsDowned() then
					v:GivePoints(200, "Carpenter")
				end
			end
		end)

		return max -- We apply our own internal duration!
	end or nil,
	LoopSound = Sound("nzu/powerups/carpenter/loop.wav"),
	EndSound = Sound("nzu/powerups/carpenter/end.wav"),
})

nzu.RegisterPowerup("Nuke", {
	Name = "Nuke",
	Model = Model("models/nzu/powerups/nuke.mdl"),
	Color = Color(255,255,100),
	Global = true,
	Function = SERVER and function(pos)
		local pos = pos or Vector()
		local zombs = nzu.Round:GetZombies()
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

		timer.Simple(max, function()
			for k,v in pairs(nzu.Round:GetPlayers()) do
				if not v:GetIsDowned() then
					v:GivePoints(400, "Nuke")
				end
			end
		end)
	end or function()
		surface.PlaySound("nzu/powerups/nuke/flash.wav")

		local num = 200
		hook.Add("HUDPaintBackground", "nzu_Nuke_Flash", function()
			surface.SetDrawColor(200, 200, 200, num)
			surface.DrawRect(0,0,ScrW(),ScrH())

			num = num - 100*FrameTime()
			if num <= 0 then
				hook.Remove("HUDPaintBackground", "nzu_Nuke_Flash")
			end
		end)
	end,
	LoopSound = Sound("nzu/powerups/carpenter/loop.wav"),
	EndSound = Sound("nzu/powerups/carpenter/end.wav")
})

nzu.RegisterPowerup("DoublePoints", {
	Name = "Double Points",
	Model = Model("models/nzu/powerups/doublepoints.mdl"),
	Color = Color(255,255,100),
	Duration = 30,
	--Negative = true,
	LoopSound = Sound("nzu/powerups/doublepoints/loop.wav"),
	EndSound = Sound("nzu/powerups/doublepoints/end.wav"),
	-- We don't do a function. Instead we have the hook below.
	Icon = Material("nzombies-unlimited/hud/powerups/doublepoints.png", "unlitgeneric smooth")
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
	--Negative = true,
	LoopSound = Sound("nzu/powerups/instakill/loop.wav"),
	EndSound = Sound("nzu/powerups/instakill/end.wav"),
	-- Same as double points
	Icon = Material("nzombies-unlimited/hud/powerups/instakill.png", "unlitgeneric smooth")
})

hook.Add("EntityTakeDamage", "InstaKill", function(ent, dmg)
	local att = dmg:GetAttacker()
	if IsValid(att) and att:IsPlayer() and att:HasPowerup("InstaKill") then -- and ent:IsZombie() -- TODO: Add this function!
		dmg:SetDamage(ent:Health()) -- Instantly kill
	end
end)

-- TODO: Make these
local firesalemusic = Sound("nzu/powerups/firesale/loop.wav")
nzu.RegisterPowerup("FireSale", {
	Name = "Fire Sale",
	Model = Model("models/nzu/powerups/firesale.mdl"),
	Color = Color(255,255,100),
	Duration = 30,
	Global = true,
	--Negative = true,
	Icon = Material("nzombies-unlimited/hud/powerups/firesale.png", "unlitgeneric smooth"),
	Function = SERVER and function()
		local shouldgiveteddy = function() return false end

		for k,v in pairs(ents.FindByClass("nzu_mysterybox")) do
			if IsValid(v.ReservedSpawnpoint) then
				v:ReserveSpawnpoint(v:GetSpawnpoint()) -- By reserving the same spawnpoint, the box will move to the same location when it is moving
			end
			v:SetPrice(10)

			v.FireSaleMusic = CreateSound(v, firesalemusic)
			v.FireSaleMusic:Play()

			v.old_teddy = v.ShouldGiveTeddy
			v.ShouldGiveTeddy = shouldgiveteddy
		end

		for k,v in pairs(nzu.GetAllMysteryBoxSpawnpoints()) do
			if not IsValid(v:GetMysteryBox()) then
				local box = nzu.CreateMysteryBox(v)
				box:SetPrice(10)
				box.nzu_FireSale = true

				box.FireSaleMusic = CreateSound(box, firesalemusic)
				box.FireSaleMusic:Play()

				box.old_teddy = box.ShouldGiveTeddy
				box.ShouldGiveTeddy = shouldgiveteddy
			end
		end
	end or nil,
	EndFunction = SERVER and function()
		for k,v in pairs(ents.FindByClass("nzu_mysterybox")) do
			-- Stop the music
			if v.FireSaleMusic then
				v.FireSaleMusic:Stop()
				v.FireSaleMusic = nil
			end

			if v.nzu_FireSale then
				v:RemoveOnClose() -- If the box was created by fire sale, remove it when it is over
			else
				v:SetPrice(950) -- Otherwise just set the price

				-- Restore the teddy roll chance function
				if v.old_teddy then
					v.ShouldGiveTeddy = v.old_teddy
					v.old_teddy = nil
				end
			end
		end
	end or nil,
})

nzu.RegisterPowerup("DeathMachine", {
	Name = "Death Machine",
	Model = Model("models/nzu/powerups/deathmachine.mdl"),
	Color = Color(255,255,100),
	Duration = 30,
	DefaultPersonal = true,
	--Negative = true,
	Icon = Material("nzombies-unlimited/hud/powerups/deathmachine.png", "unlitgeneric smooth"),
	Function = SERVER and function(pos, neg, dur, ply)
		local wep = ply:GiveWeaponInSlot("nzu_deathmachine", "Powerup")
		wep.nzu_Powerup = "DeathMachine"
	end or nil,
	EndFunction = SERVER and function(neg, ply)
		local wep = ply:GetWeapon("nzu_deathmachine")
		if IsValid(wep) then
			wep:Remove()
		end
	end or nil,
})