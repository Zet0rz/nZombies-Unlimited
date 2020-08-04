local HUD = {}

print("Loading HUD")

function HUD:Paint_Test()
	surface.SetDrawColor(255,255,255)
	surface.DrawRect(0,0,200,200)
end

function HUD:Hook_TestName(a,b,c)
	print("Ayy!", a,b,c)
end

--[[-------------------------------------------------------------------------
Points HUD
Uses panels, and thus the function is prefixed with Panel_
---------------------------------------------------------------------------]]
local point_shadow = Material("nzombies-unlimited/hud/points_shadow.png")
local point_glow = Material("nzombies-unlimited/hud/points_glow.vmt")

local selfsize = 50
local othersize = 35

local namefont = "nzu_Font_Points_NameLarge"
local othernamefont = "nzu_Font_Points_NameSmall"
local pointsfont = "nzu_Font_Points_PointsLarge"
local pointsfont2 = "nzu_Font_Points_PointsSmall"

function HUD:Panel_Points()
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
					surface.SetMaterial(point_shadow)
					surface.SetDrawColor(0,0,0,255)
					surface.DrawTexturedRect(0,0,w,h)

					surface.SetMaterial(point_glow)
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

	-- Return the panel so the HUD can remove it when it should be cleaned up
	return pnl
end

return HUD