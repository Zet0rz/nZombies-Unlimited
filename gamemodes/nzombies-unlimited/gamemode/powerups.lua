local PLAYER = FindMetaTable("Player")

-- Negative Powerups: Identified by prepending "-" in front of the ID (For example: "-doublepoints")
local function isneg(id)
	if string.sub(id, 1, 1) == "-" then
		return true, string.sub(id, 2)
	end
	return false, id
end

-------------------------
-- Localize
local pairs = pairs
local IsValid = IsValid
local math = math
local getplayers = nzu.GetSpawnedPlayers
local table = table
-----------------

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
Active Powerups & Checks
-- Note: Clients are only aware of global powerups, and their own personal ones
---------------------------------------------------------------------------]]
local globalactives = {}
local playeractives = {}

-- Get the end time of a globally active powerup
function nzu.GetPowerupTime(id)
	return globalactives[id]
end

-- Get the end time of a powerup for a player, only looking at personal powerups
function PLAYER:GetPersonalPowerupTime(id)
	return playeractives[self] and playeractives[self][id]
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
-- 		Note: To get JUST whether it is globally active, use nzu.GePowerupTime (just use the result as boolean)
function PLAYER:HasPowerup(id)
	return globalactives[id] or playeractives[self] and playeractives[self][id]
end



--[[-------------------------------------------------------------------------
Spawning Powerups (SERVER)
---------------------------------------------------------------------------]]
if SERVER then
	function nzu.CreatePowerup(id, pos, personal)
		local neg, real_id = isneg(id)
		local powerup = powerups[real_id]
		if not powerup then return end

		local drop = ents.Create("nzu_powerup")
		drop:SetPowerup(id)
		drop:SetPersonal(powerup.PlayerBased and personal)
		drop:SetNegative(neg)
		drop:SetPos(pos)
		drop:Spawn()
		return drop
	end

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
	hook.Add("nzu_ZombieKilled", "nzu_Powerups_Drop", function(z)
		if dropsthisround < maxperround and math.random(chance) == 1 then
			local area = navmesh.GetNearestNavArea(z:GetPos())
			if IsValid(area) and not nzu.IsNavAreaOutOfBounds(area) then -- and area is not out of bounds: TODO

				local id = table.remove(droplist, #droplist)
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
	end)


	--[[-------------------------------------------------------------------------
	Powerups Activation & Networking (Locals - Usable global functions down below!)
	---------------------------------------------------------------------------]]
	util.AddNetworkString("nzu_powerups_activation")
	local function networkupdate(id, neg, time, ply)
		net.Start("nzu_powerups_activation")
			net.WriteString(id) -- ID of the powerup (prior to negation)
			net.WriteBool(neg) -- Whether it is negative or not

		if ply then
			net.WriteBool(true) -- True: This is a personal powerup
			net.WriteBool(true) -- True: We ACTIVATED the powerup
			if time then net.WriteFloat(time) end -- If time is given, the powerup is duration-based. We send the end time.
			net.Send(ply)
		else
			net.WriteBool(false) -- False: This is a global powerup
			net.WriteBool(true) -- Ditto as above, but Acivation and Time is always sent after Personal
			if time then net.WriteFloat(time) end
			net.Broadcast()
		end
	end

	local function networkupdate_deactivate(id, neg, ply)
		net.Start("nzu_powerups_activation")
			net.WriteString(id)
			net.WriteBool(neg)

		if ply then
			net.WriteBool(true)
			net.WriteBool(false) -- False: We DEACTIVATE this powerup!
			net.Send(ply)
		else
			net.WriteBool(false)
			net.WriteBool(false) -- Same as above, but it is sent after personal
			net.Broadcast()
		end
	end

	local function runfunctionforplayers(plys, powerup, id, pos, neg)
		for k,v in pairs(plys) do
			if not playeractives[v] or not playeractives[v][id] then
				powerup.Function(pos, v, neg)
			end
		end
	end

	local function runfunctionglobal(powerup, id, pos, neg)
		if powerup.PlayerBased then
			runfunctionforplayers(getplayers(), powerup, id, pos, neg)
		else
			powerup.Function(pos, neg) -- If it isn't PlayerBased, run activation as global
		end
	end

	local function dodeactivate_global(powerup, id, neg)
		globalactives[id] = nil

		local tonetworkupdate = {}
		local toend = powerup and powerup.EndFunction
		local toend_playerbased = toend and powerup.PlayerBased
		for k,v in pairs(getplayers()) do
			if not playeractives[v] or not playeractives[v][id] then -- The player does not have a personal version going on of this powerup
				table.insert(tonetworkupdate, v)
				if toend_playerbased then
					powerup.EndFunction(true, v, neg)
				end
			end
		end

		if toend and not toend_playerbased then
			powerup.EndFunction(true, neg)
		end

		networkupdate_deactivate(id, neg, not table.IsEmpty(tonetworkupdate) and tonetworkupdate)
	end

	local function dodeactivate_personal(powerup, id, neg, ply, toend)
		playeractives[ply][id] = nil
		if table.IsEmpty(playeractives[ply]) then playeractives[ply] = nil end

		if toend then
			powerup.EndFunction(true, ply, neg)
		end
	end

	--[[-------------------------------------------------------------------------
	Powerups Activation (Usable functions)
	---------------------------------------------------------------------------]]
	-- id: The ID of the powerup to be activated. Use "-" in front to make negative
	-- pos: The position from which to activate the powerup from (powerups like Nukes may use this)
	-- ply: The player who it should be activated for. Nil = global
	-- dur: The duration to activate the powerup for. Overrides the powerup's own Duration. Nil = default
	function nzu.ActivatePowerup(id, pos, ply, dur)
		local neg, real_id = isneg(id)
		local powerup = powerups[real_id]
		if not powerup or (neg and not powerup.Negative) then return end

		if ply and powerup.PlayerBased then -- Activate for a player or list of players (only if the powerup supports it!)
			local plys = IsValid(ply) and {ply} or ply -- If it's not a single valid player, it's expected to be a table of players

			if powerup.Duration then -- If it is duration-based
				local newtime = CurTime() + (dur or powerup.Duration)

				for k,v in pairs(plys) do
					if not playeractives[v] then playeractives[v] = {} end
					local time = playeractives[v][id]

					if not time then
						playeractives[v][id] = newtime

						if powerup.Function then powerup.Function(pos, v, neg) end
					elseif newtime > time then
						playeractives[v][id] = newtime
					end
				end
				networkupdate(real_id, neg, newtime, plys)
			else
				if powerup.Function then runfunctionforplayers(plys, powerup, id, pos, neg) end
				networkupdate(real_id, neg, nil, plys)
			end

			hook.Run("nzu_Powerups_PowerupActivated", real_id, dur, neg, pos, ply)
		else -- Activate globally (This happens if a powerup is not player-based, even if a player is passed)
			if powerup.Duration then
				local newtime = CurTime() + (dur or powerup.Duration)
				local time = globalactives[id]

				-- We only do any internal updating if the new time is higher than the old
				if not time or newtime > time then
					globalactives[id] = newtime

					if not time and powerup.Function then
						runfunctionglobal(powerup, id, pos, neg)
					end
					networkupdate(real_id, neg, newtime)
				end
			else
				if powerup.Function then runfunctionglobal(powerup, id, pos, neg) end
				networkupdate(real_id, neg, nil)
			end

			-- Run the hook! The player passed is nil if it is not PlayerBased (even if "ply" was passed!)
			hook.Run("nzu_Powerups_PowerupActivated", real_id, dur, neg, pos)
		end
	end

	-- Deactivate a powerup. This can be done prematurely. Specifying "ply" makes it deactivate only for that player/list of players.
	-- Note: If the powerup was activated globally, deactivating it from a player does NOT remove it from that player (as it is still global!)
	function nzu.EndPowerup(id, ply)
		local neg, real_id = isneg(id)
		local powerup = powerups[real_id]

		if ply then -- Deactivate for players
			local plys = IsValid(ply) and {ply} or ply
			local tonetworkupdate = {}
			local toend = powerup and powerup.PlayerBased and powerup.EndFunction and not globalactives[id]
			for k,v in pairs(plys) do
				if playeractives[v] and playeractives[v][id] then
					dodeactivate_personal(powerup, real_id, neg, v, toend)
					table.insert(tonetworkupdate, v)
				end
			end

			if not table.IsEmpty(tonetworkupdate) then
				networkupdate_deactivate(real_id, neg, tonetworkupdate)
				hook.Run("nzu_Powerups_PowerupTerminated", real_id, neg, tonetworkupdate)
			end
		elseif globalactives[id] then -- Disable globally. But only does anything if it is ACTIVE to begin with!
			dodeactivate_global(powerup, real_id, neg)
			hook.Run("nzu_Powerups_PowerupTerminated", real_id, neg)
		end
	end



	--[[-------------------------------------------------------------------------
	Hooks and Control of powerup durations and players
	---------------------------------------------------------------------------]]

	-- This function is hooked to Think whenever a powerup is active in time
	local function checkpowerups()
		local CT = CurTime()
		for k,v in pairs(globalactives) do
			if CT > v then
				local neg, real_id = isneg(k)
				local powerup = powerups[real_id]

				dodeactivate_global(powerup, real_id, neg)
				hook.Run("nzu_Powerups_PowerupEnded", real_id, neg)
			end
		end
		for k,v in pairs(playeractives) do
			for k2,v2 in pairs(v) do
				if CT > v2 then
					local neg, real_id = isneg(k2)
					local powerup = powerups[real_id]

					dodeactivate_personal(powerup, real_id, neg, k, powerup and powerup.PlayerBased and powerup.EndFunction and not globalactives[id])
					networkupdate_deactivate(real_id, neg, k)
					hook.Run("nzu_Powerups_PowerupEnded", real_id, neg, k)
				end
			end
		end
	end
	hook.Add("Think", "nzu_Powerups_TimerControl", checkpowerups)

	-- When a player drops in, apply all global powerups to him that are PlayerBased
	hook.Add("nzu_PlayerInitialSpawned", "nzu_Powerups_ApplyGlobals", function(ply)
		for k,v in pairs(globalactives) do
			local neg, real_id = isneg(id)
			local powerup = powerups[real_id]

			if powerup and powerup.PlayerBased and powerup.Function then
				powerup.Function(nil, ply, neg) -- No position for drop-ins
			end
		end
	end)

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
					powerup.EndFunction(true, ply, neg)
				end

				removed[k] = true
			end
			playeractives[ply] = nil
		end
		for k,v in pairs(globalactives) do
			if not removed[k] then -- Not already deactivated for this player
				local neg, real_id = isneg(id)
				local powerup = powerups[real_id]

				if powerup and powerup.PlayerBased and powerup.EndFunction then
					powerup.EndFunction(true, ply, neg)
				end
			end
		end
	end
	hook.Add("nzu_PlayerUnspawned", "nzu_Powerups_UnspawnPowerups", removeply) -- Unspawning = Removal of all active powerups
	hook.Add("PlayerDisconnected", "nzu_Powerups_DisconnectPowerups", removeply) -- Disconnecting also cleans up that player

	local function fullreset()
		local playerbased = {}
		for k,v in pairs(globalactives) do
			local neg, real_id = isneg(id)
			local powerup = powerups[real_id]

			if powerup and powerup.EndFunction then
				if powerup.PlayerBased then
					playerbased[id] = {powerup, neg}
				else
					powerup.EndFunction(true, neg)
				end
			end
		end
		globalactives = {}

		for k,v in pairs(getplayers()) do
			for k2,v2 in pairs(playerbased) do
				v2[1].EndFunction(true, v, v2[2])
			end
			if playeractives[v] then
				for k2,v2 in pairs(playeractives[v]) do
					if not playerbased[k2] then
						local neg2, real_id2 = isneg(k2)
						local powerup2 = powerups[real_id2]
						if powerup2 and powerup2.EndFunction then
							powerup2.EndFunction(true, v, neg2)
						end
					end
				end
				playeractives[v] = nil
			end
		end
	end

	hook.Add("nzu_RoundStateChanged", "nzu_Powerups_FullReset", function(round, state)
		if state == ROUND_WAITING then fullreset() end
	end)
else
	--[[-------------------------------------------------------------------------
	Client Powerups Activation & Networking (Locals - Usable functions down below!)
	---------------------------------------------------------------------------]]
	local activepowerups = {}

	net.Receive("nzu_powerups_activation", function()
		local real_id = net.ReadString()
		local neg = net.ReadBool()
		local id = neg and "-"..real_id or real_id
		local personal = net.ReadBool()

		print("Reading:", real_id, neg, id, personal)

		if net.ReadBool() then
			print("Activating!")
			local powerup = powerups[real_id]
			local time = powerup and powerup.Duration and net.ReadFloat()

			-- SOUNDS :D
			if powerup and powerup.Sound then
				sound.Play(powerup.Sound, LocalPlayer():GetPos(), 0, neg and 50 or 100, 1)
			end
			local ann = nzu.GetRandomAnnouncerSound("Powerups", id)
			if ann then sound.Play(ann, LocalPlayer():GetPos(), 0, neg and 50 or 100, 1) end

			-- Duration-based Activation (for HUD and tables)
			if time then
				local tbl
				if personal then
					tbl = playeractives[LocalPlayer()]
					if not tbl then
						tbl = {}
						playeractives[LocalPlayer()] = tbl
					end
				else
					tbl = globalactives
				end
				tbl[id] = time

				local found = false
				for k,v in pairs(activepowerups) do
					if v.Key == id then
						v.Time = math.max(v.Time, time)
						found = true
						break
					end
				end
				if not found then
					local t = {Time = time, ID = real_id, Negative = neg, Key = id, Powerup = powerup}
					if powerup and powerup.LoopSound then
						local s = CreateSound(LocalPlayer(), powerup.LoopSound)
						s:PlayEx(0.5, neg and 50 or 100)
						t.Sound = s
					end
					table.insert(activepowerups, t)
				end
			end


			hook.Run("nzu_Powerups_PowerupActivated", real_id, time and time - CurTime(), neg, nil, personal and LocalPlayer())
		else
			print("Deactivating!")
			-- Deactivate powerup

			local tbl = personal and playeractives[LocalPlayer()] or globalactives
			local tbl2 = personal and globalactives or playeractives[LocalPlayer()]

			tbl[id] = nil
			for k,v in pairs(activepowerups) do
				if v.Key == id then
					if tbl2 and tbl2[id] then
						v.Time = tbl2[id]
					else
						table.remove(activepowerups, k)
					end
					break
				end
			end

			if personal and table.IsEmpty(tbl) then
				playeractives[LocalPlayer()] = nil
			end

			hook.Run("nzu_Powerups_PowerupEnded", real_id, neg, personal and LocalPlayer())
		end
	end)

	-- Internal hook: On the game going to the Waiting state, reset all awareness of powerups
	local function fullreset()
		activepowerups = {}
		globalactives = {}
		playeractives[LocalPlayer()] = nil
	end
	hook.Add("nzu_RoundStateChanged", "nzu_Powerups_FullReset", function(round, state)
		if state == ROUND_WAITING then fullreset() end
	end)
	hook.Add("nzu_PlayerUnspawned", "nzu_Powerups_UnspawnPowerups", function(ply)
		if ply == LocalPlayer() then fullreset() end
	end)

	--[[-------------------------------------------------------------------------
	HUD Components + Fallback function
	---------------------------------------------------------------------------]]
	local font = "nzu_Font_Bloody_Large"
	local col_pos = color_white
	local col_neg = Color(255,150,150)
	--[[nzu.HUDComponent("Powerups", function() return activepowerups end, function(hud, ups)
		local w = ScrW()/2
		for k,v in pairs(ups) do
			draw.SimpleText(v.Name .. ": " .. math.ceil(v.Time - CurTime()), font, w, ScrH()*0.85 - k*50, v.Negative and col_neg or col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		draw.SimpleText("Hello", font, w, ScrH()*0.85, col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end)]]
	hook.Add("HUDPaint", "nzu_Powerups_DevHUD", function()
		local w = ScrW()/2
		for k,v in pairs(activepowerups) do
			draw.SimpleText(v.Powerup.Name .. ": " .. math.ceil(v.Time - CurTime()), font, w, ScrH()*0.85 - k*50, v.Negative and col_neg or col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end)
end