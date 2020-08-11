
--[[-------------------------------------------------------------------------
Announcer
For the most part, these sounds are identified through IDs which are networked
to clients who themselves play the sound file. However the resource set
is shared so that sounds CAN be played on Server if need to be

IDs are typically prefixed by the extension they come from
i.e. "PowerUps_MaxAmmo" or "MysteryBox_BoxLeave"
---------------------------------------------------------------------------]]
local announcerpath = "nzu/announcer/"
local SETTINGS = nzu.GetExtension("core")

local function selectsound(path)
	-- TODO: Support searching folder for sounds to support random picking
	-- Also TODO: Support any sound file extension
	return path..".wav"
end

function nzu.GetAnnouncerSound(path)
	return announcerpath..SETTINGS.Announcer.."/"..selectsound(path)
end

if CLIENT then
	local queue
	local function doannouncer(path, noqueue)
		local snd = announcerpath..SETTINGS.Announcer.."/"..path
		if noqueue then
			surface.PlaySound(snd)
		else
			if queue then
				table.insert(queue, snd)
			else
				surface.PlaySound(snd)

				queue = {}
				local nextsound = CurTime() + SoundDuration(snd) - 0.2
				hook.Add("Think", "nzu_Announcer_SoundQueue", function()
					if CurTime() > nextsound then
						local s2 = table.remove(queue, 1)
						if s2 then
							surface.PlaySound(s2)
							nextsound = CurTime() + SoundDuration(s2) - 0.2
						else
							queue = nil
							hook.Remove("Think", "nzu_Announcer_SoundQueue")
						end
					end
				end)
			end
		end
	end

	function nzu.Announcer(path, noqueue)
		doannouncer(selectsound(path), noqueue)
	end

	net.Receive("nzu_announcer", function()
		local path = net.ReadString()
		local noqueue = net.ReadBool()
		doannouncer(path, noqueue)
	end)
else
	util.AddNetworkString("nzu_announcer")

	-- Playing it on the server networks it to clients, however the queue for each client may vary
	function nzu.Announcer(path, noqueue, ply)
		net.Start("nzu_announcer")
			net.WriteString(selectsound(path))
			net.WriteBool(noqueue or false)
		if ply then net.Send(ply) else net.Broadcast() end
	end
end