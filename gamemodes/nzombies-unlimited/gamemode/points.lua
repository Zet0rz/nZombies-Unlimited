local PLAYER = FindMetaTable("Player")

-- Use these NetworkVars or use NW2Int?
nzu.AddPlayerNetworkVar("Int", "Points")

function PLAYER:CanAfford(cost)
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

	function PLAYER:GivePoints(n)
		n = hook.Run("nzu_PlayerGivePoints", self, n) or n
		self:SetPoints(self:GetPoints() + n)

		notifyplayers(self, n)
	end

	function PLAYER:TakePoints(n)
		n = hook.Run("nzu_PlayerTakePoints", self, n) or n
		self:SetPoints(self:GetPoints() - n)

		notifyplayers(self, -n)
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
	local function dopoints(ent, dmg)
		if ent.nzu_ShouldGivePoints then
			local ply = dmg:GetAttacker()
			if IsValid(ply) and ply:IsPlayer() then
				if dmg:GetDamage() >= ent:Health() then
					if knifetypes[dmg:GetDamageType()] then
						ply:GivePoints(130)
					else
						ply:GivePoints(hitboxes[util.QuickTrace(dmg:GetDamagePosition(), dmg:GetDamagePosition()).HitGroup] or 50)
					end
				else
					ply:GivePoints(10)
				end
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

	hook.Add("EntityTakeDamage", "nzu_Test", dopoints)
end

if CLIENT then
	net.Receive("nzu_PointsNotify", function()
		local ply = net.ReadEntity()
		local n = net.ReadInt(32)
		hook.Run("nzu_PlayerPointNotify", ply, n)
	end)
end

--[[-------------------------------------------------------------------------
HUD Component
---------------------------------------------------------------------------]]
if CLIENT then

	--local mat = Material("models/combine_dropship/combine_fenceglow")
	--local mat = Material("models/props_combine/tpballglow")
	local mat = Material("nzombies-unlimited/hud/points_shadow.png")
	local mat2 = Material("nzombies-unlimited/hud/points_glow.vmt")

	local selfsize = 50
	local othersize = 35

	local namefont = "nzu_Font_Points_NameLarge"
	local othernamefont = "nzu_Font_Points_NameSmall"
	local pointsfont = "nzu_Font_Points_PointsLarge"
	local pointsfont2 = "nzu_Font_Points_PointsSmall"
	
	--nzu.RegisterHUDComponentType("HUD_Points")
	nzu.RegisterHUDComponent("HUD_Points", "Unlimited", {
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
						local b = v == LocalPlayer()
						local size = b and selfsize or othersize

						local p = self:Add("DPanel")
						p:Dock(BOTTOM)
						p:SetZPos(b and 0 or 1)
						p:SetTall(size)
						p:SetPaintBackground(false)
						p.Player = v
						p:DockMargin(0,0,selfsize - size,2)

						p.Avatar = p:Add("nzu_PlayerAvatar")
						p.Avatar:SetPlayer(v)
						p.Avatar:Dock(LEFT)
						p.Avatar:SetWide(size)
						p.Avatar:DockMargin(0,0,5,0)

						p.Name = p:Add("DLabel")
						p.Name:SetText(v:Nick())
						p.Name:Dock(TOP)
						p.Name:SetFont(b and namefont or othernamefont)
						--p.Name:SetTall(b and 20 or 10)
						p.Name:SizeToContentsY()
						p.Name:SetContentAlignment(1)
						function p.Name.Think(s)
							local n = v:Nick()
							if n ~= s:GetText() then
								s:SetText(n)
							end
						end

						p.Points = p:Add("DLabel")
						p.Points:SetText(0)
						p.Points:SetFont(b and pointsfont or pointsfont2)
						p.Points:Dock(FILL)
						p.Points:SetTextColor(color_white)
						if b then p.Points:SetContentAlignment(1) end
						function p.Points.Think(s)
							local points = v:GetPoints()
							if points ~= s.Points then
								s:SetText(points)
								s.Points = points
							end
						end

						function p.Think(s)
							if v:Team() ~= lteam then
								s:Remove()
								self.Players[v] = nil
							end
						end

						function p.Points.Think(s)
							s:SetText(v:GetPoints())
						end

						function p.Paint(s,w,h)
							surface.SetMaterial(mat)
							surface.SetDrawColor(0,0,0,255)
							surface.DrawTexturedRect(0,0,w,h)

							surface.SetMaterial(mat2)
							surface.SetDrawColor(p.Avatar.R - 100, p.Avatar.G - 100, p.Avatar.B - 100,255)
							surface.DrawTexturedRect(b and 50 or 30,0,w-(b and 49 or 29),h)
						end

						p.PointNotifies = {}
						local x = b and 200 or 150
						local y = b and 20 or 10
						local totaltime = 1
						function p.PaintOver(s,w,h)
							local ct = CurTime()
							
							local num = #s.PointNotifies
							local i = 1
							while i <= num do
								local v = s.PointNotifies[i]
								local pct = (ct - v[3])/totaltime
								local points = v[1]

								surface.SetTextColor(255,points > 0 and 255 or 0,0,255 - pct*255)
								surface.SetTextPos(x + pct*50, y + pct*v[2])
								surface.SetFont("Trebuchet24")
								surface.DisableClipping(true)
								surface.DrawText(points)
								surface.DisableClipping(false)

								if pct >= 1 then
									s.PointNotifies[i] = s.PointNotifies[num]
									table.remove(s.PointNotifies)
									num = num - 1
								else
									i = i + 1
								end
							end
						end

						--p:SetBackgroundColor(Color(255,0,0))
						self.Players[v] = p
					end
				end
			end

			hook.Add("nzu_PlayerPointNotify", pnl, function(s, ply, n)
				local p = s.Players[ply]
				if p then
					table.insert(p.PointNotifies, {n, math.random(-20,20), CurTime()})
				end
			end)

			return pnl
		end,
		Remove = function(pnl)
			hook.Remove("nzu_PlayerPointNotify", pnl)
			pnl:Remove()
		end,
	})
end