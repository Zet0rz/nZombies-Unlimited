-- Include the Drop Entity
include("entity.lua")

local EXT = nzu.Extension()
local Settings = EXT.Settings

EXT.Powerups = EXT.Powerups or {}
function EXT.AddPowerup(id, tbl)
	EXT.Powerups[id] = tbl
end
function EXT.GetPowerup(id) return EXT.Powerups[id] end

-------------------------
-- Localize
local Powerups = EXT.Powerups
local pairs = pairs
local IsValid = IsValid
local math = math
local getplayers = nzu.Round.GetPlayers
-----------------

-- Load all base powerups
include("base_powerups.lua")

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

	local function doactivate(id, powerup, pos, ply, dur, neg)
		local isneg
		if powerup.Negative then isneg = neg or false end
		local id2 = isneg and id.."_negative" or id

		if not powerup.PlayerBased or not ply then
			-- Check if it is already active! Just set update the time to whichever ends last

			if powerup.Duration then
				local t = CurTime() + dur
				if globalactives[id2] then
					globalactives[id2] = math.Max(globalactives[id2], t)

					net.Start("nzu_powerups_activation")
						net.WriteString(id)
						net.WriteBool(true)
						net.WriteFloat(CurTime() + dur)
						if powerup.Negative then net.WriteBool(neg) end
					net.Broadcast()

				return end
				globalactives[id2] = t
			end

			if powerup.Function then
				if powerup.PlayerBased then
					for k,v in pairs(getplayers()) do
						if not playeractives[v] or not playeractives[v][id2] then
							powerup.Function(pos, v, isneg)
						end
					end
				else
					powerup.Function(pos, isneg)
				end
			end

			net.Start("nzu_powerups_activation")
				net.WriteString(id)
				net.WriteBool(true)
				if powerup.Duration then net.WriteFloat(CurTime() + dur) end
				if powerup.Negative then net.WriteBool(neg) end
			net.Broadcast()
		else
			local plys = IsValid(ply) and {ply} or ply -- Valid player = single table of it, otherwise take 'ply' directly: Supports a table of players
			local t = powerup.Duration and CurTime() + dur
			for k,v in pairs(plys) do
				if t then
					if not playeractives[v] then playeractives[v] = {} end
					if not EXT.PlayerHasPowerup(v, id2) then -- The player doesn't have the powerup active (neither global nor personal) - We need to run the function on this player
						playeractives[v][id2] = t
						if powerup.Function then powerup.Function(pos, v, dur, isneg) end
					else
						local t2 = playeractives[v][id2]
						if not t2 or t2 < t then playeractives[v][id2] = t end
					end
				else
					if powerup.Function then powerup.Function(pos, v, isneg) end
				end
			end

			net.Start("nzu_powerups_activation")
				net.WriteString(id)
				net.WriteBool(true)
				if powerup.Duration then net.WriteFloat(CurTime() + dur) end
				if powerup.Negative then net.WriteBool(neg) end
			net.Send(plys)
		end
	end
	local function dodeactivate(id, powerup, ply, neg, terminate)
		local isneg
		if powerup.Negative then isneg = neg or false end
		local id2 = isneg and id.."_negative" or id

		if not powerup.PlayerBased or not ply then
			if globalactives[id2] then
				globalactives[id2] = nil

				if powerup.PlayerBased then
					local netplys = {}
					for k,v in pairs(getplayers()) do
						if not EXT.PlayerHasPowerup(v, id2) then
							if powerup.EndFunction then powerup.EndFunction(terminate, v, isneg) end
							table.insert(netplys, v)
						end
					end

					net.Start("nzu_powerups_activation")
						net.WriteString(id)
						net.WriteBool(false)
						if powerup.Negative then net.WriteBool(neg or false) end
					net.Send(netplys)
				else
					if powerup.EndFunction then powerup.EndFunction(terminate, isneg) end

					net.Start("nzu_powerups_activation")
						net.WriteString(id)
						net.WriteBool(false)
						if powerup.Negative then net.WriteBool(neg or false) end
					net.Broadcast()
				end
			end
		else
			local plys = IsValid(ply) and {ply} or ply
			for k,v in pairs(plys) do
				local ups = playeractives[v]
				if ups and ups[id2] then
					ups[id2] = nil
					if not globalactives[id2] and powerup.EndFunction then -- Not globally active either, run the End Function
						powerup.EndFunction(terminate, v, isneg)
					end
				end
			end
			net.Start("nzu_powerups_activation")
				net.WriteString(id)
				net.WriteBool(false)
				if powerup.Negative then net.WriteBool(neg or false) end
			net.Send(plys)
		end
	end

	util.AddNetworkString("nzu_powerups_activation")
	function EXT.ActivatePowerup(id, pos, ply, dur, neg)
		local powerup = Powerups[id]
		if not powerup or (neg and not powerup.Negative) then return end
		-- ply is supported with non-personal, in which case it just applies globally anyway

		doactivate(id, powerup, pos, ply, dur or powerup.Duration, neg)

		net.Start("nzu_powerups_activation")
			net.WriteString(id)
			net.WriteBool(true)
			if powerup.Duration then net.WriteFloat(CurTime() + (dur or powerup.Duration)) end
			if powerup.Negative then net.WriteBool(neg) end
		if ply then net.Send(ply) else net.Broadcast() end

		hook.Run("nzu_Powerups_PowerupActivated", id, ply, dur, neg)
	end

	function EXT.EndPowerup(id, ply, neg)
		local powerup = Powerups[id]
		if not powerup or (neg and not powerup.Negative) then return end

		dodeactivate(id, powerup, ply, neg, true)

		net.Start("nzu_powerups_activation")
			net.WriteString(id)
			net.WriteBool(false)
			net.WriteBool(neg)
		if ply then net.Send(ply) else net.Broadcast() end

		hook.Run("nzu_Powerups_PowerupEnded", id, ply, neg)
	end

	local function determineneg(k)
		if string.sub(k, #k-8) == "_negative" then
			return string.sub(k, 0, #k-9)
		end
	end

	-- Hook to control deactivation of times
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
	local function removeply(ply)
		if playeractives[ply] then
			local tbl = playeractives[ply]
			for k,v in pairs(tbl) do
				local neg = determineneg(k)
				local k2 = neg or k
				local powerup = Powerups[k2]
				tbl[k] = nil
				if powerup and powerup.EndFunction then
					powerup.EndFunction(true, ply, neg and true or false)
				end
			end
		end
	end

else
	local activepowerups = {}
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

	local function activate(id, powerup, endtime, neg)
		if powerup.EndSound then surface.PlaySound(powerup.EndSound) end
		nzu.Announcer("PowerUps_"..id) -- TODO: If Announcer is categorized, apply here?

		local t2 = activepowerups[id]
		if not t2 or t2 < endtime then -- Apply the time if and only if it is greater than whatever was active, or nothing was active
			activepowerups[id] = endtime 
		end

		hook.Run("nzu_Powerups_PowerupActivated", id, endtime - CurTime(), neg)
	end

	net.Receive("nzu_powerups_activation", function()
		local id = net.ReadString()
		if not net.ReadBool() then
			local neg = net.ReadBool()
			local id2 = neg and id.."_negative" or id
			if activepowerups[id2] then
				local powerup = Powerups[id]
				if powerup and powerup.EndSound then surface.PlaySound(powerup.EndSound) end

				activepowerups[id2] = nil
				hook.Run("nzu_Powerups_PowerupEnded", id, neg)
			end
		return end

		local powerup = Powerups[id]
		if not powerup then return end

		local endtime,neg
		if powerup.Duration then endtime = net.ReadFloat() end
		if powerup.Negative then neg = net.ReadBool() end

		activate(id, powerup, endtime, neg)
	end)
end

function EXT.PlayerHasNegativePowerup(ply, id) return EXT.PlayerHasPowerup(ply, id.."_negative") end
function EXT.GetPlayerNegativePowerupTime(ply, id) return EXT.GetPlayerPowerupTime(ply, id.."_negative") end