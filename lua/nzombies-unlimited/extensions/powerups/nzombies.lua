-- Include the Drop Entity
include("entity.lua")

local EXT = nzu.Extension()
local Settings = EXT.Settings

EXT.Powerups = EXT.Powerups or {}
function EXT.AddPowerup(id, tbl)
	EXT.Powerups[id] = tbl
end
function EXT.GetPowerup(id) return EXT.Powerups[id] end
function EXT.GetAllPowerups() return EXT.Powerups end
function EXT.GetDroppablePowerups()
	local tbl = {}
	for k,v in pairs(EXT.Powerups) do
		if not v.Undroppable then
			table.insert(tbl, k)
		end
	end
end

-------------------------
-- Localize
local Powerups = EXT.Powerups
local pairs = pairs
local IsValid = IsValid
local math = math
local getplayers = nzu.GetSpawnedPlayers
-----------------

-- Load all base powerups
include("base_powerups.lua")

-- Powerups with appended _negative are negative variants
-- This function returns the original id if the passed is negative
local function determineneg(k)
	if string.sub(k, #k-8) == "_negative" then
		return string.sub(k, 0, #k-9)
	end
end

if SERVER then
	include("powerupsystem.lua")

	local globalactives = {}
	local playeractives = {}

	function EXT.GetPlayerPowerupTime(ply, id)
		if IsValid(ply) and playeractives[ply] and playeractives[ply][id] then
			if globalactives[id] then
				return math.Max(globalactives[id], playeractives[ply][id])
			end
			return playeractives[ply][id]
		end
		return globalactives[id]
	end
	function EXT.GetGlobalPowerupTime(id) return globalactives[id] end
	function EXT.GetGlobalNegativePowerupTime(id) return EXT.GetGlobalPowerupTime(id.."_negative") end

	function EXT.PlayerHasPowerup(ply, id)
		if globalactives[id] then return true end
		local ups = IsValid(ply) and playeractives[ply]
		if ups and ups[id] then return true end

		return false
	end

	--[[-------------------------------------------------------------------------
	Powerup Activation & Neworking
	---------------------------------------------------------------------------]]
	util.AddNetworkString("nzu_powerups_activation")
	util.AddNetworkString("nzu_powerups_sound")
	local function updateplayer(id, ply, time, neg, forced)
		net.Start("nzu_powerups_activation")
			net.WriteString(id)
			if neg ~= nil then net.WriteBool(neg) end
			net.WriteBool(true)
			if time ~= nil then net.WriteFloat(time) end
			net.WriteBool(forced or false)
		if ply then net.Send(ply) else net.Broadcast() end
	end

	local function deactivateplayer(id, ply, neg)
		net.Start("nzu_powerups_activation")
			net.WriteString(id)
			if neg ~= nil then net.WriteBool(neg) end
			net.WriteBool(false)
		if ply then net.Send(ply) else net.Broadcast() end
	end

	local function doannouncer(id, ply, neg)
		net.Start("nzu_powerups_activation")
			net.WriteString(id)
			if neg ~= nil then net.WriteBool(neg) end
		if ply then net.Send(ply) else net.Broadcast() end
	end

	local function doactivate(id, powerup, pos, ply, dur, neg)
		local isneg
		if powerup.Negative then isneg = neg or false end
		local id2 = isneg and id.."_negative" or id

		doannouncer(id, ply, isneg)

		-- Activate globally
		if not powerup.PlayerBased or not ply then
			local toactivate = true
			if powerup.Duration then
				local t = CurTime() + dur
				if globalactives[id2] then -- Already active
					if globalactives[id2] >= t then return end -- Also a higher time, return
					toactivate = false
				end

				globalactives[id2] = t
				updateplayer(id, nil, t, isneg)
			else
				updateplayer(id, nil, nil, isneg) -- Update with no duration = Proc activation
			end

			if powerup.Function then
				if powerup.PlayerBased then
					for k,v in pairs(getplayers()) do
						if not playeractives[v] or not playeractives[v][id2] then
							powerup.Function(pos, v, isneg) -- Activate function on all players that don't have the powerup already
						end
					end
				elseif toactivate then
					powerup.Function(pos, isneg)
				end
			end
		else -- Activate for a set of players
			local plys = IsValid(ply) and {ply} or ply -- Valid player = single table of it, otherwise take 'ply' directly: Supports a table of players
			local t = powerup.Duration and CurTime() + dur
			local gt = globalactives[id2]

			for k,v in pairs(plys) do
				if not v:IsUnspawned() then
					if t then
						local tbl = playeractives[v]
						local toactivate
						if not tbl then -- Player doesn't have any powerup table at all
							tbl = {}
							tbl[id2] = t
							playeractives[v] = tbl
							toactivate = not gt -- Activate if not in globals
						else
							local pt = tbl[id2]
							toactivate = not pt and not gt -- Activate if not in player or globals
							if not pt or pt < t then tbl[id2] = t end
						end

						if toactivate and powerup.Function then
							powerup.Function(pos, v, isneg)
						end
					elseif powerup.Function then
						powerup.Function(pos, v, isneg)
					end
				end
			end

			updateplayer(id, plys, t, isneg)
		end
	end

	local function dodeactivate(id, powerup, ply, neg, terminate)
		local isneg
		if powerup.Negative then isneg = neg or false end
		local id2 = isneg and id.."_negative" or id

		-- Deactivate globally
		if not powerup.PlayerBased or not ply then
			if globalactives[id2] then -- Only if already active globally
				globalactives[id2] = nil -- Remove it!

				if powerup.PlayerBased then -- Player-based: Loop through all players and deactivate ONLY for those that have the time!
					local nets = {} -- The players we need to network to
					for k,v in pairs(getplayers()) do
						if not playeractives[v] or not playeractives[v][id2] then -- This player does not have a personal version of this powerup
							table.insert(nets, v)
							if powerup.EndFunction then powerup.EndFunction(terminate, v, isneg) end
						end
					end

					deactivateplayer(id, nets, isneg)
				else
					if powerup.EndFunction then
						powerup.EndFunction(terminate, isneg)
					end
					deactivateplayer(id, nil, isneg) -- Network All players deactivation if the powerup can't be player-based
				end
			end
			-- If not globally active, either means not active right now or not Duration supported
			-- Either way, this won't do anything (EndFunction does not apply to non-Durations)
		else
			-- Deactivate for set player(s)
			-- We must remember that if a global is still active, we need to update these players to this time
			-- and not run EndFunction, rather than deactivating them completely
			local plys = IsValid(ply) and {ply} or ply
			local gt = globalactives[id2]

			local nets = {}
			for k,v in pairs(plys) do
				if playeractives[v] and playeractives[v][id2] then -- It's active for them!
					playeractives[v][id2] = nil
					if table.IsEmpty(playeractives) then playeractives[v] = nil end -- Cleanup
					if not gt and powerup.EndFunction then powerup.EndFunction(terminate, v, isneg) end
					table.insert(nets, v) -- This player is affected
				end
			end

			if gt then -- A global is active, force-update the time for all affected players to the global's time
				updateplayer(id, nets, gt, isneg, true)
			else -- No global active, deactivate for all affected players
				deactivateplayer(id, nets, isneg)
			end
		end
	end

	--[[-------------------------------------------------------------------------
	Extension Functions
	---------------------------------------------------------------------------]]
	function EXT.ActivatePowerup(id, pos, ply, dur, neg)
		local powerup = Powerups[id]
		if not powerup or (neg and not powerup.Negative) then return end
		-- ply is supported with non-personal, in which case it just applies globally anyway

		doactivate(id, powerup, pos, ply, dur or powerup.Duration, neg)
		hook.Run("nzu_Powerups_PowerupActivated", id, ply, dur, neg)
	end

	function EXT.EndPowerup(id, ply, neg)
		local powerup = Powerups[id]
		if not powerup or (neg and not powerup.Negative) then return end

		dodeactivate(id, powerup, ply, neg, true)
		hook.Run("nzu_Powerups_PowerupEnded", id, ply, neg)
	end

	--[[-------------------------------------------------------------------------
	Hooks and Control of powerup durations and players
	---------------------------------------------------------------------------]]
	hook.Add("Think", "nzu_Powerups_TimerControl", function()
		local CT = CurTime()
		for k,v in pairs(globalactives) do
			if CT > v then
				local neg = determineneg(k)
				local k2 = neg or k
				dodeactivate(k2, Powerups[k2], neg and true or false)
			end
		end
		for k,v in pairs(playeractives) do
			for k2,v2 in pairs(v) do
				if CT > v2 then
					local neg = determineneg(k2)
					local k3 = neg or k2
					dodeactivate(k3, Powerups[k3], k, neg and true or false)
				end
			end
		end
	end)

	-- Function for if a player drops out, is disconnects, or otherwise removed
	-- Clean this player's table, along with running EndFunction for all powerups
	-- that are PlayerBased and active on him
	local function removeply(ply)
		local ups = {}
		if playeractives[ply] then
			for k,v in pairs(playeractives[ply]) do
				local neg = determineneg(k)
				local k2 = neg or k
				local powerup = Powerups[k2]

				if powerup and powerup.EndFunction then
					powerup.EndFunction(true, ply, neg and true or false)
				end

				ups[k] = true
			end
			playeractives[ply] = nil
		end
		for k,v in pairs(globalactives) do
			if not ups[k] then -- Not already deactivated for this player
				local neg = determineneg(k)
				local k2 = neg or k
				local powerup = Powerups[k2]

				if powerup and powerup.PlayerBased and powerup.EndFunction then
					powerup.EndFunction(true, ply, neg and true or false)
				end
			end
		end
	end
	hook.Add("nzu_PlayerUnspawned", "nzu_Powerups_UnspawnPowerups", removeply) -- Unspawning = Removal of all active powerups
	hook.Add("PlayerDisconnected", "nzu_Powerups_DisconnectPowerups", removeply) -- Disconnecting also cleans up that player

	-- When a player drops in, apply all global powerups to him
	hook.Add("nzu_PlayerInitialSpawned", "nzu_Powerups_ApplyGlobals", function(ply)
		for k,v in pairs(globalactives) do
			local neg = determineneg(k)
			local k2 = neg or k
			local powerup = Powerups[k2]

			if powerup and powerup.PlayerBased and powerup.Function then
				powerup.Function(nil, ply, neg and true or false) -- No position for drop-ins
			end
		end
	end)

else

	--[[-------------------------------------------------------------------------
	Client Receiving of update packets
	---------------------------------------------------------------------------]]
	local activepowerups = {}
	local function activate(id, powerup, endtime, neg, forced)
		for k,v in pairs(activepowerups) do
			if v.ID == id and v.Negative == neg then
				if forced or v.Time < endtime then v.Time = endtime end
				return
			end
		end

		local t = {ID = id, Negative = neg, Time = endtime, Name = powerup.Name}
		if powerup.LoopSound then
			local s = CreateSound(LocalPlayer(), powerup.LoopSound)
			s:PlayEx(0.5, neg and 50 or 100)
			t.Sound = s
		end
		table.insert(activepowerups, t)

		hook.Run("nzu_Powerups_PowerupActivated", id, endtime and endtime - CurTime(), neg)
	end

	net.Receive("nzu_powerups_activation", function()
		local id = net.ReadString()
		local powerup = Powerups[id]
		if not powerup then return end

		local isneg
		if powerup.Negative then isneg = net.ReadBool() end

		if not net.ReadBool() then
			for k,v in pairs(activepowerups) do
				if v.ID == id and v.Negative == isneg then
					if v.Sound then v.Sound:Stop() end
					table.remove(activepowerups, k)
					if powerup and powerup.EndSound then surface.PlaySound(powerup.EndSound) end
					break
				end
			end
		else
			local endtime
			if powerup.Duration then endtime = net.ReadFloat() end
			activate(id, powerup, endtime, neg, net.ReadBool())
		end
	end)

	-- The Announcer/Activation sound
	net.Receive("nzu_powerups_sound", function()
		local id = net.ReadString()
		local powerup = Powerups[id]
		if not powerup then return end

		local isneg
		if powerup.Negative then isneg = net.ReadBool() end

		local pitch = isneg and 50 or 100
		if powerup.Sound then sound.Play(powerup.Sound, LocalPlayer():GetPos(), 0, pitch, 1) end

		local ann = nzu.GetRandomAnnouncerSound("Powerups", id)
		if ann then sound.Play(ann, LocalPlayer():GetPos(), 0, pitch, 1) end
	end)

	function EXT.GetPlayerPowerupTime(ply, id)
		if ply or ply == LocalPlayer() then
			return activepowerups[id] -- Since the client always only knows the highest time of itself and globals (which it won't know the difference between)
		end
	end

	function EXT.PlayerHasPowerup(ply, id)
		if ply == LocalPlayer() then
			return activepowerups[id] and true or false
		end
	end

	hook.Add("nzu_PlayerUnspawned", "nzu_Powerups_UnspawnPowerups", function(ply)
		if ply == LocalPlayer() then activepowerups = {} end
	end)

	--[[-------------------------------------------------------------------------
	HUD Components + Fallback function
	---------------------------------------------------------------------------]]
	local font = "nzu_Font_Bloody_Large"
	local col_pos = color_white
	local col_neg = Color(255,150,150)
	nzu.HUDComponent("Powerups", function() return activepowerups end, function(hud, ups)
		local w = ScrW()/2
		for k,v in pairs(ups) do
			draw.SimpleText(v.Name .. ": " .. math.ceil(v.Time - CurTime()), font, w, ScrH()*0.85 - k*50, v.Negative and col_neg or col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		draw.SimpleText("Hello", font, w, ScrH()*0.85, col_pos, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end)
end

-- Negative Wrappers just append _negative to the end of IDs
function EXT.PlayerHasNegativePowerup(ply, id) return EXT.PlayerHasPowerup(ply, id.."_negative") end
function EXT.GetPlayerNegativePowerupTime(ply, id) return EXT.GetPlayerPowerupTime(ply, id.."_negative") end