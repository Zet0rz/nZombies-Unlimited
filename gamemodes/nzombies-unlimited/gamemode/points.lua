local PLAYER = FindMetaTable("Player")

-- Use these NetworkVars or use NW2Int?
nzu.AddPlayerNetworkVar("Int", "Points")

function PLAYER:CanAfford(cost)
	if cost < 0 then return true end -- Always able to afford negative values
	return cost <= self:GetPoints()
end

if SERVER then
	util.AddNetworkString("nzu_PointsNotify")
	local function notifyplayers(ply, n)
		net.Start("nzu_PointsNotify")
			net.WriteEntity(ply)
			net.WriteInt(n, 32)
		net.Broadcast()

		hook.Run("nzu_PlayerPointNotify", ply, n)
	end

	function PLAYER:GivePoints(n, type, ent)
		local tbl = {Points = n}
		hook.Run("nzu_PlayerGivePoints", self, tbl, type, ent)
		local n = tbl.Points
		if n ~= 0 then
			self:SetPoints(self:GetPoints() + n)
			notifyplayers(self, n)
		end
	end

	function PLAYER:TakePoints(n, type, ent)
		local tbl = {Points = n}
		hook.Run("nzu_PlayerTakePoints", self, tbl, type, ent)
		local n = tbl.Points
		if n ~= 0 then
			self:SetPoints(self:GetPoints() - n)
			notifyplayers(self, -n)
		end
	end

	local knifetypes = {
		[DMG_CRUSH] = true,
		[DMG_SLASH] = true,
		[DMG_CLUB] = true
	}
	local hitboxes = {
		[HITGROUP_HEAD] = 100,
		[HITGROUP_CHEST] = 60,
	}
	local function dopoints(ent, dmg, hitgroup)
		if ent.nzu_ShouldGivePoints then
			local ply = dmg:GetAttacker()
			if IsValid(ply) and ply:IsPlayer() then
				local points,typ
				local iskill = dmg:GetDamage() >= ent:Health()
				if ent.DamagePoints then points,typ = ent:DamagePoints(dmg, hitgroup, ply) else
					if iskill then
						if knifetypes[dmg:GetDamageType()] then
							points,typ = 130, "ZombieKnifeKill"
						else
							points = hitboxes[hitgroup] or 50
							typ = "ZombieKill"
						end
						ent.nzu_ShouldGivePoints = nil
					else
						points = 10
						typ = "ZombieHit"
					end
				end
				if iskill then ply:AddFrags(1) end
				ply:GivePoints(points,typ,ent)
			end
		end
	end

	local ENTITY = FindMetaTable("Entity")
	function ENTITY:ShouldGivePoints(b)
		--[[if b then
			if not self.nzu_ShouldGivePoints then
				print("Applying points to zombie")
				self.nzu_OriginalOnTakeDamage = self.OnTakeDamage

				 -- This isn't called on non-SENTs D:
				self.OnTakeDamage = function(self, dmg)
					print("C")
					self:nzu_OriginalOnTakeDamage(dmg)

					local p = dmg:GetPoints()
					if p then
						dmg:GetAttacker():GivePoints(p)
					end
				end
			end
		elseif self.nzu_ShouldGivePoints then
			self.OnTakeDamage = self.nzu_OriginalOnTakeDamage
			self.nzu_OriginalOnTakeDamage = nil
		end]]

		self.nzu_ShouldGivePoints = b
	end

	-- Functions to insert point giving into a damage info object
	-- It uses a weak table to annotate the damageinfom  but without preventing it front being garbage collected
	-- See "Weak Tables" in Lua

	--[[local dmg_points = setmetatable({}, {__mode = "k"})

	local CTAKEDAMAGEINFO = FindMetaTable("CTakeDamageInfo")
	function CTAKEDAMAGEINFO:SetPoints(n)
		dmg_points[self] = n
	end

	function CTAKEDAMAGEINFO:GetPoints()
		return dmg_points[self]
	end]]

	hook.Add("PostEntityTakeDamage", "nzu_Points_ZombieDamage", dopoints)

	hook.Add("nzu_PlayerInitialSpawned", "nzu_Points_StartPoints", function(ply)
		local s = nzu.GetExtension("Core")
		ply:SetPoints(s and s.Settings and s.Settings.StartPoints or 500)
	end)
end

if CLIENT then
	net.Receive("nzu_PointsNotify", function()
		local ply = net.ReadEntity()
		local n = net.ReadInt(32)
		hook.Run("nzu_PlayerPointNotify", ply, n)
	end)
end