local PLAYER = FindMetaTable("Player")
local SETTINGS = nzu.GetExtension("core")

-------------------------
-- Localize
local pairs = pairs
local IsValid = IsValid
local math = math
local getplayers = nzu.GetSpawnedPlayers
local table = table
-----------------

-- Local tables listing all currently active powerups and the time they will end
local globalactives = {}
local playeractives = {}

-- Lua refresh
for k,v in pairs(getplayers()) do
	playeractives[v] = {}
end
--

-- Negative Powerups: Identified by prepending "-" in front of the ID (For example: "-DoublePoints")
local function isneg(id)
	if string.sub(id, 1, 1) == "-" then
		return true, string.sub(id, 2)
	end
	return false, id
end

--[[-------------------------------------------------------------------------
Adding and Getting Powerups, Utility
---------------------------------------------------------------------------]]
local powerups = {}
function nzu.RegisterPowerup(id, data)
	powerups[id] = data
end

function nzu.GetPowerup(id) return powerups[id] end
function nzu.GetAllPowerups() return powerups end
function nzu.GetDroppablePowerups()
	local tbl = {}
	for k,v in pairs(powerups) do
		if not v.Undroppable then
			table.insert(tbl, k)
		end
	end
end


--[[-------------------------------------------------------------------------
SHARED FUNCTIONS
Getters & Accessors
---------------------------------------------------------------------------]]
-- Get the end time of a globally active powerup
function nzu.GetPowerupTime(id)
	return globalactives[id]
end

-- Get the end time of a powerup for a player, only looking at personal powerups
function PLAYER:GetPersonalPowerupTime(id)
	return playeractives[self][id]
end

-- Get the end time of a powerup for a player, taking into account both personal and global actives
-- It returns the max of the two
function PLAYER:GetPowerupTime(id)
	local time1 = playeractives[self] and playeractives[self][id]
	local time2 = globalactives[id]

	if time1 then
		if time2 then return math.max(time1, time2) end
		return time1
	end
	return time2
end

-- Return whether the player has access to the powerup at all (either personally active or globally active)
-- 		Note: Use PLAYER:GetPersonalPowerupTime for personal-only checks (just use the result as boolean)
-- 		Note: To get JUST whether it is globally active, use nzu.GetPowerupTime (just use the result as boolean)
function PLAYER:HasPowerup(id)
	return (globalactives[id] or playeractives[self][id]) and true or false
end


--[[-------------------------------------------------------------------------
Local functions: Timed Activation & Deactivation
---------------------------------------------------------------------------]]
local function check_powerups()
	local ct = CurTime()
	for k,v in pairs(globalactives) do
		if ct > v then
			globalactives[k] = nil

			-- End the powerup
			local neg, real_id = isneg(k)
			local powerup = powerups[real_id]

			if powerup and powerup.EndFunction then
				if powerup.Global then
					powerup.EndFunction(neg, nil, false)
				else
					for k2,v2 in pairs(getplayers()) do
						if not playeractives[v2] and playeractives[v2][k] then powerup.EndFunction(neg, v2, false) end
					end
				end
			end

			hook.Run("nzu_PowerupEnded", real_id, neg)
		end
	end

	local empty = true
	for k,v in pairs(playeractives) do
		for k2,v2 in pairs(v) do
			if ct > v2 then
				v[k2] = nil

				-- End the powerup for this player
				local neg, real_id = isneg(k2)
				local powerup = powerups[real_id]

				if powerup and powerup.EndFunction and not globalactives[k2] then powerup.EndFunction(neg, k, false) end
				hook.Run("nzu_PowerupEnded_Personal", real_id, neg, k)
			else
				empty = false
			end
		end
	end

	if empty and table.IsEmpty(globalactives) then
		hook.Remove("Think", "nzu_Powerups_TimerControl")
	end
end

--[[-------------------------------------------------------------------------
Powerup Activation (Shared)
---------------------------------------------------------------------------]]
local function activate_powerup(powerup, id, time, dur, real_id, neg, pos, plys)
	-- First; Hook the Think function if there are no active powerups
	hook.Add("Think", "nzu_Powerups_TimerControl", check_powerups)
	--[[if table.IsEmpty(globalactives) then -- If there are no global powerups active
		local any = false
		for k,v in pairs(playeractives) do -- Go through each player
			if not table.IsEmpty(v) then -- If any player has a non-empty powerup table, we break
				any = true
				break
			end
		end

		-- If no player have non-empty powerup tables, we hook
		if not any then
			hook.Add("Think", "nzu_Powerups_TimerControl", check_powerups)
		end
	end]]

	-- If players are passed, it HAS to be non-Global
	if plys then
		local f = not globalactives[id] and powerup.Function -- We only grab the function if it is not already globally active

		-- If "plys" is valid, it's a single player
		if IsValid(plys) then
			
			-- If the player does not have the powerup active at all, we set the time and run the function (if it was grabbed)
			if not playeractives[plys][id] then
				playeractives[plys][id] = time
				if f then f(pos, neg, dur, plys) end

			-- Else, if the player has it active but it ends in a shorter time, we update the time (and not run the function)
			elseif playeractivse[plys][id] < time then
				playeractives[plys][id] = time
			end

			-- Hook call; This runs regardless of whether the player has it active or not, and whether it was even a longer time than previously active
			hook.Run("nzu_PowerupActivated_Personal", real_id, neg, dur, plys)
		else

			-- It is a table of players, we loop through them all and do the same
			for k,v in pairs(plys) do
				if not playeractives[v][id] then
					playeractives[v][id] = time
					if f then f(pos, neg, dur, v) end
				elseif playeractivse[v][id] < time then
					playeractives[v][id] = time
				end
				hook.Run("nzu_PowerupActivated_Personal", real_id, neg, dur, v)
			end
		end
	else

		-- If the powerup is Global, first get old previous time
		local oldtime = globalactives[id]

		-- If there was no previous old time, the powerup was not already active globally
		-- We then set the time
		if not oldtime then
			globalactives[id] = time

			-- If it is global, we know it wasn't previously active so we just run the function
			if powerup.Global then
				if powerup.Function then powerup.Function(pos, neg, dur) end

			-- Else, it is player-based. We must loop through all players and run it only on those that don't have it personally active
			else
				local f = powerup.Function
				for k,v in pairs(getplayers()) do
					if not playeractives[v][id] and f then
						f(pos, neg, v)
					end
				end
			end

		-- Otherwise if it is already globally active, we just update the time if it is smaller
		elseif oldtime < time then
			globalactives[id] = time
		end

		-- Run the hook; Again, it is regardless of actual activation
		hook.Run("nzu_PowerupActivated", real_id, neg, dur)
	end
end

--[[-------------------------------------------------------------------------
Powerup Termination (Shared)
---------------------------------------------------------------------------]]
local function terminate_powerup(powerup, id, real_id, neg, plys)
	if plys then
		local f = not globalactives[id] and powerup.EndFunction

		if IsValid(plys) then
			playeractives[plys][id] = nil
			if f then f(neg, plys, true) end
			hook.Run("nzu_PowerupTerminated_Personal", real_id, neg, plys)
		else
			for k,v in pairs(plys) do
				playeractives[v][id] = nil
				if f then f(neg, v, true) end
				hook.Run("nzu_PowerupActivated_Personal", real_id, neg, v)
			end
		end
	else
		globalactives[id] = nil
		if powerup.Global then
			if powerup.EndFunction then powerup.EndFunction(neg, nil, true) end
		else
			local f = powerup.EndFunction
			for k,v in pairs(getplayers()) do
				if not playeractives[v][id] then
					f(neg, v, true)
				end
			end
		end
		hook.Run("nzu_PowerupTerminated", real_id, neg)
	end
end


--[[-------------------------------------------------------------------------
Players disconnecting/unspawning
---------------------------------------------------------------------------]]

-- Function for if a player drops out, is disconnects, or otherwise removed
-- Clean this player's table, along with running EndFunction for all powerups
-- that are PlayerBased and active on him
local function removeply(ply)
	local removed = {}
	if playeractives[ply] then
		for k,v in pairs(playeractives[ply]) do
			local neg, real_id = isneg(k)
			local powerup = powerups[real_id]

			if powerup and powerup.EndFunction then
				powerup.EndFunction(ply, neg, true)
			end

			removed[k] = true
		end
		playeractives[ply] = nil
	end
	for k,v in pairs(globalactives) do
		if not removed[k] then -- Not already deactivated for this player
			local neg, real_id = isneg(id)
			local powerup = powerups[real_id]

			if powerup and not powerup.Global and powerup.EndFunction then
				powerup.EndFunction(ply, neg, true)
			end
		end
	end
end
hook.Add("nzu_PlayerUnspawned", "nzu_UnspawnPowerups", removeply) -- Unspawning = Removal of all active powerups
if SERVER then hook.Add("PlayerDisconnected", "nzu_DisconnectPowerups", removeply) end -- Disconnecting also cleans up that player

--[[-------------------------------------------------------------------------
Players dropping in
Dropping in, powerups table initialized, and run all non-Global powerups that are globally active on this player
---------------------------------------------------------------------------]]
hook.Add("nzu_PlayerInitialSpawned", "nzu_InitializePowerups", function(ply)
	if SERVER or ply == LocalPlayer() then
		playeractives[ply] = {}

		for k,v in pairs(globalactives) do
			local neg, real_id = isneg(k)
			local powerup = powerups[real_id]

			if powerup and not powerup.Global and powerup.Function then
				-- Pos is nil when dropping in
				powerup.Function(nil, neg, v - CurTime(), ply)
			end
		end
	end
end)

--[[-------------------------------------------------------------------------
Game Over, resetting powerups
This only needs to be done for globals, as the player ones are removed when
the player is Unspawned (after game over)
---------------------------------------------------------------------------]]
hook.Add("nzu_GameOverSequence", "nzu_PowerupsFullReset", function()
	local removed = {}
	for k,v in pairs(globalactives) do
		local neg, real_id = isneg(id)
		local powerup = powerups[real_id]

		if powerup and powerup.EndFunction then
			if powerup.Global then
				powerup.EndFunction(neg, true)
			else
				for k,v in pairs(getplayers()) do
					powerup.EndFunction(v, neg, true)
				end
			end
		end

		removed[k] = true
	end

	for k,v in pairs(playeractives) do
		for k2,v2 in pairs(v) do
			if not removed[k2] then
				local neg, real_id = isneg(k2)
				local powerup = powerups[real_id]

				powerup.EndFunction(k, neg, true)
			end
		end
		playeractives[k] = {} -- We don't actually FULLY remove the powerup table for this player, to avoid errors in runtime functions
		-- They will be automatically removed when the player has Unspawned (post Game Over)
	end
	globalactives = {}
	hook.Remove("Think", "nzu_Powerups_TimerControl")
end)

if SERVER then
	--[[-------------------------------------------------------------------------
	Local functions: Networking
	---------------------------------------------------------------------------]]
	util.AddNetworkString("nzu_powerups")
	local function network_activate(id, neg, time, personal, plys)
		net.Start("nzu_powerups")
			net.WriteString(id)
			net.WriteBool(neg)
			net.WriteBool(personal)
			net.WriteBool(true) -- Activated
			if time then
				net.WriteBool(true)
				net.WriteFloat(time)
			else
				net.WriteBool(false)
			end
		if plys then net.Send(plys) else net.Broadcast() end
	end

	local function network_terminate(id, neg, plys)
		net.Start("nzu_powerups")
			net.WriteString(id)
			net.WriteBool(neg)
			net.WriteBool(plys and true or false)
			net.WriteBool(false) -- Terminated
		if plys then net.Send(plys) else net.Broadcast() end
	end

	-- Players joining in should be made aware of global powerups
	hook.Add("PlayerInitialSpawned", "nzu_InitializePowerups", function(ply)
		for k,v in pairs(globalactives) do
			local neg, real_id = isneg(k)
			network_activate(real_id, neg, v, false, ply)
		end
	end)

	--[[-------------------------------------------------------------------------
	The Powerup Cycle system (Also includes hooks to let you modify it! :D)
	---------------------------------------------------------------------------]]
	local droplist = {}
	local dropsthisround = 0

	local function repopulatedroplist()
		droplist = hook.Run("nzu_PopulatePowerupDropList") or nzu.GetDroppablePowerups()
		-- Either given by a hook, or just the list of all default droppable powerups

		hook.Run("nzu_PowerupDropList", droplist) -- This hook runs when it is generated. It can potentially be used to modify it further (but probably shouldn't!)
	end

	hook.Add("nzu_GameStarted", "nzu_Powerups_Reset", function()
		repopulatedroplist()
		dropsthisround = 0
	end)

	hook.Add("nzu_RoundChanged", "nzu_Powerups_ResetCount", function()
		dropsthisround = 0
	end)

	--[[-------------------------------------------------------------------------
	The drop system
	---------------------------------------------------------------------------]]
	local chance = 50 -- 1 in 50 = 2%
	local maxperround = 4
	local function zombiekilled(z)
		if dropsthisround < maxperround and math.random(chance) == 1 then
			local area = navmesh.GetNearestNavArea(z:GetPos())
			if IsValid(area) and not nzu.IsNavAreaOutOfBounds(area) then

				local id = table.remove(droplist, #droplist) -- TODO: Right now, this is not random, it always just takes the drops in order
				local powerup = nzu.GetPowerup(id)
				if powerup then
					nzu.CreatePowerup(up, z:GetPos(), powerup.DefaultPersonal)
					dropsthisround = dropsthisround + 1
				end

				if #droplist == 0 then
					repopulatedroplist()
				end
			end
		end
	end
	
	-- Enable/Disable drop hook
	function SETTINGS:OnEnablePowerupsChanged(old, new)
		if new then
			hook.Add("nzu_ZombieKilled", "nzu_PowerupsDrop", zombiekilled)
		else
			hook.Remove("nzu_ZombieKilled", "nzu_PowerupsDrop")
		end
	end

	-- And remember to hook it based on the current value!
	if SETTINGS.EnablePowerups then
		hook.Add("nzu_ZombieKilled", "nzu_PowerupsDrop", zombiekilled)
	end

	--[[-------------------------------------------------------------------------
	Global functions: Activation & Creation
	---------------------------------------------------------------------------]]

	function nzu.CreatePowerup(id, pos, personal)
		local neg, real_id = isneg(id)
		local powerup = powerups[real_id]
		if not powerup then return end

		local drop = ents.Create("nzu_powerup")
		drop:SetPowerup(real_id)
		drop:SetPersonal(not powerup.Global and personal)
		drop:SetNegative(neg)
		drop:SetPos(pos)
		drop:SetPowerupDuration(10)
		--drop:SetLifetime(30)
		drop:Spawn()
		return drop
	end

	function DebugTest()
		local pos = Entity(1):GetEyeTrace().HitPos
		local spacing = 50

		local i = 1
		for k,v in pairs(powerups) do
			nzu.CreatePowerup(k, pos + Vector(i*spacing, 0, 0))
			if not v.Global then
				nzu.CreatePowerup(k, pos + Vector(i*spacing, spacing, 0), true)
			end
			if v.Negative then
				nzu.CreatePowerup("-"..k, pos + Vector(i*spacing, spacing*2, 0))
				if not v.Global then
					nzu.CreatePowerup("-"..k, pos + Vector(i*spacing, spacing*3, 0), true)
				end
			end
			i = i + 1
		end
	end

	-- Activate a powerup. This runs the effect if it is not already active, and otherwise updates the time if it is longer than previously active
	-- Passing a "-" in front of the ID makes it negative. Pass pos to give a position for positional powerups (such as Carpenter and Nuke)
	-- Passing ply as a single player or table of players will activate it personally for these players, if the powerup is not Global (otherwise it will globally activate!)
	-- Passing dur will set the duration of the powerup. Not passing it will make it default.
	function nzu.ActivatePowerup(id, pos, ply, dur)
		local neg, real_id = isneg(id)
		local powerup = powerups[real_id]
		if not powerup or (neg and not powerup.Negative) then return end

		local plys = not powerup.Global and ply
		local time = powerup.Duration and CurTime() + (dur or powerup.Duration)
		if time then
			activate_powerup(powerup, id, time, dur, real_id, neg, pos, plys)
		elseif powerup.Function then
			if powerup.Global then
				time = powerup.Function(pos, neg)
			else
				if IsValid(plys) then
					time = powerup.Function(pos, neg, nil, plys)
				else
					for k,v in pairs(plys or getplayers()) do
						time = powerup.Function(pos, neg, nil, v)
					end
				end
			end
		end
		network_activate(real_id, neg, time, plys and true or false, plys)
	end

	-- Terminate a powerup. This will make it end prematurely. Specifying "ply" makes it deactivate only for that player/list of players.
	-- Note: If the powerup was activated globally, deactivating it from a player does NOT remove it from that player (as it is still global!)
	function nzu.TerminatePowerup(id, ply)
		local neg, real_id = isneg(id)
		local powerup = powerups[real_id]

		if ply then -- Deactivate for players
			local toterminate
			local plys = IsValid(ply) and {ply} or ply

			if IsValid(ply) then
				if playeractives[ply][id] then
					toterminate = ply
				else return end
			else
				local toterminate = {}
				for k,v in pairs(plys) do
					if playeractives[v][id] then
						table.insert(toterminate, v)
					end
				end

				if table.IsEmpty(toterminate) then return end
			end

			terminate_powerup(powerup, id, real_id, neg, toterminate)
			network_terminate(real_id, neg, toterminate)
		elseif globalactives[id] then
			terminate_powerup(powerup, id, real_id, neg)
			network_terminate(real_id, neg)
		end
	end
else
	local loopsounds = {}
	local hiddentimedloopsounds = {}

	local function checkloopsounds()
		local ct = CurTime()
		for k,v in pairs(hiddentimedloopsounds) do
			if v.Time < ct then
				if v.Sound then v.Sound:Stop() end

				local neg, real_id = isneg(k)
				local powerup = powerups[real_id]
				if powerup and powerup.EndSound then
					sound.Play(powerup.EndSound, LocalPlayer():GetPos(), 0, neg and 75 or 100, 1)
				end
				
				hiddentimedloopsounds[k] = nil
			end
		end

		if table.IsEmpty(hiddentimedloopsounds) then
			hook.Remove("Think", "nzu_PowerupSoundTimer")
		end
	end

	net.Receive("nzu_powerups", function()
		local real_id = net.ReadString()
		local neg = net.ReadBool()
		local personal = net.ReadBool()

		local powerup = powerups[real_id] or {}
		local id = neg and "-"..real_id or real_id

		if net.ReadBool() then
			local time = net.ReadBool() and net.ReadFloat()
			if not powerup.Duration then
				if powerup.Function then
					powerup.Function(nil, neg, nil, personal and LocalPlayer())
				end
			else
				activate_powerup(powerup, id, time, time and time - CurTime(), real_id, neg, nil, personal and LocalPlayer()) -- Pos is always nil on client (can network it if it is useful?)
			end

			-- If the powerup has a sound, play it :D
			if powerup.Sound then
				sound.Play(powerup.Sound, LocalPlayer():GetPos(), 0, neg and 75 or 100, 1)
			end

			-- If time is passed, we do loop sounds
			if time then
				if powerup.Duration then
					if not loopsounds[id] then
						local s = CreateSound(LocalPlayer(), powerup.LoopSound)
						s:PlayEx(0.5, neg and 50 or 100)
						loopsounds[id] = s
					end
				else
					local looper = hiddentimedloopsounds[id]
					if looper then
						if looper.Time < time then looper.Time = time end
					else
						local s
						if powerup.LoopSound then
							s = CreateSound(LocalPlayer(), powerup.LoopSound)
							s:PlayEx(0.5, neg and 50 or 100)
						end

						hiddentimedloopsounds[id] = {Sound = s, Time = time}
						hook.Add("Think", "nzu_PowerupSoundTimer", checkloopsounds)
					end
				end
			end

			-- 1 Second later, play the announcer voice line
			timer.Simple(1, function()
				local ann = nzu.GetAnnouncerSound("powerups/"..string.lower(real_id))
				if ann then sound.Play(ann, LocalPlayer():GetPos(), 0, neg and 75 or 100, 1) end
			end)
		else
			terminate_powerup(powerup, id, real_id, neg, personal and LocalPlayer())
			endsounds(id, powerup)
		end
	end)

	local function endloopsound(id, real_id, neg)
		if loopsounds[id] then
			loopsounds[id]:Stop()
			loopsounds[id] = nil
		end

		local powerup = powerups[real_id]
		if powerup and powerup.EndSound then
			sound.Play(powerup.EndSound, LocalPlayer():GetPos(), 0, neg and 75 or 100, 1)
		end
	end
	hook.Add("nzu_PowerupEnded_Personal", "nzu_PowerupLoopSoundEnd",  function(real_id, neg, k)
		local id = neg and "-"..real_id or real_id
		if k == LocalPlayer() and not globalactives[id] then
			endloopsound(id, real_id, neg)
		end
	end)
	hook.Add("nzu_PowerupEnded", "nzu_PowerupLoopSoundEnd",  function(real_id, neg)
		local id = neg and "-"..real_id or real_id
		local plytbl = playeractives[LocalPlayer()]

		if not plytbl or not plytbl[id] then
			endloopsound(id, real_id, neg)
		end
	end)

	local font = "nzu_Font_Bloody_Large"
	local col_pos = color_white
	local col_neg = Color(255,150,150)
	hook.Add("HUDPaint", "nzu_Powerups_DevHUD", function()
		local w = ScrW()/2
		local i = 1

		for k,v in pairs(globalactives) do
			local neg, real_id = isneg(k)
			draw.SimpleText(k .. ": " .. math.ceil(v - CurTime()), font, w, ScrH()*0.85 - i*50, neg and col_neg or col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			i = i + 1
		end
		draw.SimpleText("Global Actives", font, w, ScrH()*0.85 - i*50, neg and col_neg or col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if playeractives[LocalPlayer()] then
			i = i + 2
			for k,v in pairs(playeractives[LocalPlayer()]) do
				local neg, real_id = isneg(k)
				draw.SimpleText(k .. ": " .. math.ceil(v - CurTime()), font, w, ScrH()*0.85 - i*50, neg and col_neg or col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				i = i + 1
			end
			draw.SimpleText("Player Actives", font, w, ScrH()*0.85 - i*50, neg and col_neg or col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end)
end