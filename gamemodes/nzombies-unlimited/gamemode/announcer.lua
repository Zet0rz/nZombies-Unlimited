
--[[-------------------------------------------------------------------------
Announcer
For the most part, these sounds are identified through IDs which are networked
to clients who themselves play the sound file. However the resource set
is shared so that sounds CAN be played on Server if need to be

IDs are typically prefixed by the extension they come from
i.e. "PowerUps_MaxAmmo" or "MysteryBox_BoxLeave"
---------------------------------------------------------------------------]]
local res = nzu.GetResourceSet("announcer")
function nzu.GetAnnouncerSounds(id)
	return res[id]
end

function nzu.GetRandomAnnouncerSound(id)
	local tbl = res[id]
	if tbl then
		return tbl[math.random(#tbl)]
	end
end

if CLIENT then
	local queue
	function nzu.Announcer(id, q)
		local s = nzu.GetRandomAnnouncerSound(id)
		if s then
			if q then
				if queue then
					table.insert(queue, s)
				else
					surface.PlaySound(s)

					queue = {}
					local nextsound = CurTime() + SoundDuration(s) - 0.2
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
			else
				surface.PlaySound(s)
			end
		end
	end

	net.Receive("nzu_announcer", function()
		local id = net.ReadString()
		local q = net.ReadBool()
		nzu.Announcer(id, q)
	end)
else
	util.AddNetworkString("nzu_announcer")
	function nzu.Announcer(id, q, ply)
		net.Start("nzu_announcer")
			net.WriteString(id)
			net.WriteBool(q or false)
		if ply then net.Send(ply) else net.Broadcast() end
	end
end