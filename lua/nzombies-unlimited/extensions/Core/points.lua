
-- Use these NetworkVars or use NW2Int?
nzu.AddPlayerNetworkVar("Int", "Points")

if SERVER then
	local PLAYER = FindMetaTable("Player")

	function PLAYER:GivePoints(n)
		n = hook.Run("nzu_PlayerGivePoints", self, n) or n
		self:SetPoints(self:GetPoints() + n)
	end

	function PLAYER:TakePoints(n)
		n = hook.Run("nzu_PlayerTakePoints", self, n) or n
		self:SetPoints(self:GetPoints() - n)
	end

	local ENTITY = FindMetaTable("Entity")
	function ENTITY:ShouldGivePoints(b)
		if b then
			if not self.nzu_ShouldGivePoints then
				self.nzu_OriginalOnTakeDamage = self.OnTakeDamage

				function self:OnTakeDamage(dmg) -- This isn't called on non-SENTs D:
					--print("C")
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
		end

		self.nzu_ShouldGivePoints = b
	end

	-- Functions to insert point giving into a damage info object
	-- It uses a weak table to annotate the damageinfom  but without preventing it front being garbage collected
	-- See "Weak Tables" in Lua

	local dmg_points = setmetatable({}, {__mode = "k"})

	local CTAKEDAMAGEINFO = FindMetaTable("CTakeDamageInfo")
	function CTAKEDAMAGEINFO:SetPoints(n)
		dmg_points[self] = n
	end

	function CTAKEDAMAGEINFO:GetPoints()
		return dmg_points[self]
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
	hook.Add("ScaleNPCDamage", "nzu_GenerateDefaultPoints", function(ent, hitgroup, dmginfo)
		if ent.nzu_ShouldGivePoints and not dmginfo:GetPoints() then
			--print("A")
			if knifetypes[dmginfo:GetDamageType()] then
				dmginfo:SetPoints(130)
			else
				dmginfo:SetPoints(hitboxes[hitgroup] or 50)
			end
		end
	end)

	hook.Add("EntityTakeDamage", "nzu_Test", function(ent, dmg)
		if ent.nzu_ShouldGivePoints then
			--print("B")
		end
	end)
end

if SERVER then
	nzu.AddPlayerNetworkVarNotify("Points", function(ply, name, old, new)
		ply:ChatPrint(old .. " -> " ..new)
	end)
end

--[[-------------------------------------------------------------------------
HUD Component
---------------------------------------------------------------------------]]
if CLIENT then
	local EXTENSION = nzu.Extension()

	EXTENSION.HUD.RegisterComponentType("Points")
	EXTENSION.HUD.RegisterComponent("Points", "Unlimited", {
		Create = function()
			local pnl = vgui.Create("DPanel")
			pnl:ParentToHUD()
			pnl:SetPos(50, 100)
			pnl:SetSize(250, ScrH() - 300)
			pnl:SetPaintBackground(false)

			pnl.Players = {}
			function pnl:Think()
				local lteam = LocalPlayer():Team()
				for k,v in pairs(team.GetPlayers(lteam)) do
					if not IsValid(self.Players[v]) then
						local p = self:Add("DPanel")
						p:Dock(BOTTOM)
						p:SetTall(50)
						p:SetPaintBackground(false)
						p.Player = v

						p.Avatar = p:Add("nzu_PlayerAvatar")
						p.Avatar:SetPlayer(v)
						p.Avatar:Dock(LEFT)
						p.Avatar:SetWide(50)

						function p.Think(s)
							if v:Team() ~= lteam then
								s:Remove()
								self.Players[v] = nil
							end
						end

						p:SetBackgroundColor(Color(255,0,0))
						self.Players[v] = p
					end
				end
			end

			return pnl
		end,
		Remove = function(pnl)
			pnl:Remove()
		end,
	})
end