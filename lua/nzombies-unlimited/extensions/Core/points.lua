local EXTENSION = nzu.Extension()

local PLY = FindMetaTable("Player")
function PLY:GetPoints() return self.nzu_Points or 0 end

if SERVER then
	local bits = 32
	util.AddNetworkString("nzu_points")
	
	function PLY:SetPoints(num)
		self.nzu_Points = num
		net.Start("nzu_points")
			net.WriteEntity(self)
			net.WriteUInt(bits, num)
		net.Broadcast()
	end
	
	function PLY:GivePoints(num)
		num = hook.Run("nzu_ModifyPlayerGetPoints", self, num) or num
		if num ~= 0 then
			self:SetPoints(self:GetPoints() + num)
			hook.Run("nzu_PlayerGetPoints", self, num)
		end
	end

	function PLY:TakePoints(num)
		self:GivePoints(-num)
	end

	hook.Add("PlayerInitialSpawn", "nzu_PointsInitialize", function(ply)
		ply:SetPoints(0)

		-- Inform the new player about everyone else's points
		for k,v in pairs(player.GetAll()) do
			if v ~= ply then
				net.Start("nzu_points")
					net.WriteEntity(v)
					net.WriteUInt(bits, v:GetPoints())
				net.Send(ply)
			end
		end
	end)

	local settings = EXTENSION.Settings
	local setting = "Starting Points"
	hook.Add("nzu_PlayerSpawn", "nzu_GiveStartingPoints", function(ply)
		ply:SetPoints(settings[setting])
	end)
else
	net.Receive("nzu_points", function()
		local ply = net.ReadEntity()
		ply.nzu_Points = net.ReadUInt(bits)
		hook.Run("nzu_PlayerGetPoints", ply, num)
	end)
end