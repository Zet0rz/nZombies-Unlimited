
HUD.Name = "Unlimited"
if SERVER then return end -- Not really necessary, but hey, we save a bit of loading and memory since the server would discard this anyway

--[[-------------------------------------------------------------------------
Round Indicator
---------------------------------------------------------------------------]]
local roundfont = "nzu_RoundNumber"
surface.CreateFont(roundfont, {
	font = "DK Umbilical Noose",
	size = 128,
	weight = 500,
	antialias = true,
})

local lastdrawnround = 0
local transitioncomplete
local transitiontime = 3

local tallysize = 150
local tallymats = {
	Material("nzombies-unlimited/hud/tally_1.png", "unlitgeneric smooth"),
	Material("nzombies-unlimited/hud/tally_2.png", "unlitgeneric smooth"),
	Material("nzombies-unlimited/hud/tally_3.png", "unlitgeneric smooth"),
	Material("nzombies-unlimited/hud/tally_4.png", "unlitgeneric smooth"),
	Material("nzombies-unlimited/hud/tally_5.png", "unlitgeneric smooth")
}
local tallyparticlepos = {
	{0,0,10,120},
	{45,0,10,120},
	{70,0,10,120},
	{115,0,-10,120},
	{115,0,-120,120},
}

local burnparticles = {
	Material("particle/particle_glow_03.vmt"),
	Material("particle/particle_glow_04.vmt"),
	Material("particle/particle_glow_05.vmt"),
	nil, -- I can't tell you why this is necessary, but it is
}
local burncolors = {
	--Color(255,255,255),
	--color_black,color_black,color_black,
	--Color(50,0,100),Color(10,0,50),Color(20,0,40),Color(50,0,20),Color(50,0,0), -- Purple shadows
	Color(50,0,0),Color(20,0,0),Color(10,0,0),Color(20,0,10),Color(50,10,0),Color(100,0,0),Color(150,0,0), -- Dark blood shadows

	Color(255,100,50),Color(255,100,0),Color(200,100,0),Color(255,100,50),Color(255,150,0), -- Burn colors
	nil,
}
local particlerate = 100
local particlesize = 20
local burnwidth = 10

local particlespeed_x = 200
local particlespeed_y = 100
local particlelife = 1

local whiterisespeed = 1.5
local initialtime = 7
local initialmove = 2

local particles
local lasttargetround = 0
local lastparticletime
local riser
local initialcounter

local ROUND = nzu.Round

function HUD:RoundIndicator()
	local CT = CurTime()
	local r = ROUND:GetRound()
	local state = ROUND:GetState()

	if riser or state == ROUND_PREPARING and r ~= 1 then
		if not riser then riser = 0 end
		riser = riser + whiterisespeed*FrameTime()
		if riser > 1 and whiterisespeed > 0 then
			if state ~= ROUND_PREPARING then
				riser = nil
			else
				riser = 1
				whiterisespeed = -whiterisespeed
			end
		elseif riser < 0 and whiterisespeed < 0 then
			riser = 0
			whiterisespeed = -whiterisespeed
		end
	end

	if not riser and r ~= lastdrawnround then
		if not transitioncomplete or lasttargetround ~= r then
			transitioncomplete = CT + transitiontime
			particles = {}
			lasttargetround = r
			lastparticletime = CT
		end
		local pct = (transitioncomplete - CT)/transitiontime
		local pct2 = math.Clamp(transitioncomplete - 2 - CT, 0, 1)
		local invpct2 = 1 - pct2

		-- Special first round display
		local px,py = 75,ScrH()-175
		if r == 1 then
			if not initialcounter then
				initialcounter = CT + initialtime
			end

			local px2 = ScrW()/2 - tallysize/5
			local py2 = ScrH()/2
			if CT > initialcounter then
				local pct3 = 1 - (CT - initialcounter)/initialmove

				if pct3 <= 0 then
					initialcounter = nil
				else
					px = px + (px2 - px)*pct3
					py = py + (py2 - py)*pct3
					surface.SetTextColor(150, 0, 0, pct3*255)
				end
			else
				px = px2
				py = py2

				local fade = 255*pct2
				surface.SetTextColor(150 + 155*pct2, fade, fade)
			end

			surface.SetFont(roundfont)
			local x,y = surface.GetTextSize(translate.Get("round"))
			surface.SetTextPos(ScrW()/2 - x/2, ScrH()/2 - y)
			surface.DrawText(translate.Get("round"))

			surface.SetMaterial(tallymats[1])
			surface.DrawTexturedRectUV(75, ScrH() - 175, tallysize, invpct2*tallysize, 0,0,1, invpct2)
		end

		if r <= 5 and r >= 0 then
			if lastdrawnround > r then
				lastdrawnround = 0
			elseif lastdrawnround <= 5 then
				local max = pct2*255
				surface.SetDrawColor(255,max,max)
				for i = 1, lastdrawnround do
					surface.SetMaterial(tallymats[i])
					surface.DrawTexturedRect(px, py, tallysize, tallysize)
				end
			end

			-- Transition with tally marks
			surface.SetDrawColor(255,pct*200,pct*100)

			local doneparticles
			for i = lastdrawnround + 1, r do
				surface.SetMaterial(tallymats[i])
				surface.DrawTexturedRectUV(px, py, tallysize, invpct2*tallysize, 0,0,1, invpct2)

				if invpct2 < 1 then
					local num = math.floor((CT - lastparticletime)*particlerate)
					if num > 0 then
						for j = 1,num do
							local x1,y1,x2,y2 = unpack(tallyparticlepos[i])
							local x = (x1 + x2*invpct2) + math.random(burnwidth) + px
							local y = (y1 + y2*invpct2) + py

							local mat = burnparticles[math.random(#burnparticles)]
							table.insert(particles, {
								X = x,
								Y = y,
								Material = mat,
								Color = burncolors[math.random(#burncolors)],
								SpeedX = math.random(-particlespeed_x, particlespeed_x),
								Time = CT
							})
						end
						doneparticles = true
					end
				end
			end

			if doneparticles then lastparticletime = CT end
		else
			surface.SetFont(roundfont)

			-- Transition with number
			local max = 255*pct2
			if lastdrawnround <= 5 then
				surface.SetDrawColor(255,max,max,max)
				for i = 1, lastdrawnround do
					surface.SetMaterial(tallymats[i])
					surface.DrawTexturedRect(px, py, tallysize, tallysize)
				end
			else
				surface.SetTextPos(px + 25, py + 10)
				surface.SetTextColor(150 + 155*pct2,max,max,max)
				surface.DrawText(lastdrawnround)
			end

			if invpct2 < 1 then
				local x,y = surface.GetTextSize(r)

				render.ClearStencil()
				render.SetStencilEnable(true)
				local y1 = py + 10
				render.ClearStencilBufferRectangle(0, y1, 400, y1 + y*invpct2, 1)

				render.SetStencilReferenceValue(1)
				render.SetStencilCompareFunction(STENCIL_EQUAL)

				surface.SetTextColor(150 + pct*100,pct*250,pct*150,255)
				surface.SetTextPos(100, y1)
				surface.DrawText(r)

				render.SetStencilEnable(false)
				
				local num = math.floor((CT - lastparticletime)*particlerate*(x*0.1))
				if num > 0 then
					for j = 1,num do
						local x2 = math.random(x) + 100
						local y2 = y1 + y*invpct2

						local mat = burnparticles[math.random(#burnparticles)]
						table.insert(particles, {
							X = x2,
							Y = y2,
							Material = mat,
							Color = burncolors[math.random(#burncolors)],
							SpeedX = math.random(-particlespeed_x, particlespeed_x),
							Time = CT
						})
					end
					lastparticletime = CT
				end
			else
				surface.SetTextColor(150 + pct*100,pct*250,pct*150,255)
				surface.SetTextPos(px + 25, py + 10)
				surface.DrawText(r)
			end
		end

		for k,v in pairs(particles) do
			local diff = (CT - v.Time)
			local x = v.X
			local y = v.Y - particlespeed_y*diff

			surface.SetMaterial(v.Material)
			local col = v.Color
			surface.SetDrawColor(col.r, col.g, col.b, (1 - diff/particlelife) * 255)
			surface.DrawTexturedRect(x,y,particlesize,particlesize)

			v.X = v.X + v.SpeedX*FrameTime()
			v.SpeedX = v.SpeedX - (v.SpeedX*FrameTime()*3)
		end

		if not initialcounter and pct <= 0 then
			lastdrawnround = r
			transitioncomplete = nil
			particles = nil
			lastparticletime = nil
		end
	else
		if lastdrawnround > 5 then
			surface.SetFont(roundfont)
			surface.SetTextPos(100, ScrH() - 165)

			if riser then
				local max = riser*255
				surface.SetTextColor(150 + riser*155,max,max)
			else
				surface.SetTextColor(150,0,0)
			end

			surface.DrawText(lastdrawnround)
		else
			if riser then
				local max = riser*255
				surface.SetDrawColor(255,max,max)
			else
				surface.SetDrawColor(255,0,0)
			end
			for i = 1, lastdrawnround do
				surface.SetMaterial(tallymats[i])
				surface.DrawTexturedRect(75, ScrH() - 175, tallysize, tallysize)
			end
		end
	end
end

--[[-------------------------------------------------------------------------
Points HUD
Uses panels, and thus the function returns a removal function
---------------------------------------------------------------------------]]
local point_shadow = Material("nzombies-unlimited/hud/points_shadow.png")
local point_glow = Material("nzombies-unlimited/hud/points_glow.vmt")

local selfsize = 50
local othersize = 35

local namefont = "nzu_Font_Points_NameLarge"
local othernamefont = "nzu_Font_Points_NameSmall"
local pointsfont = "nzu_Font_Points_PointsLarge"
local pointsfont2 = "nzu_Font_Points_PointsSmall"

function HUD:Points()
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

	-- The returned function cleans up what this function created
	return function()
		hook.Remove("nzu_PlayerPointNotify", pnl)
		pnl:Remove()
	end
end

--[[-------------------------------------------------------------------------
Damage Overlay
---------------------------------------------------------------------------]]
local min_threshold = 0.7
local max_threshold = 0.3
local pulse_threshold = 0.4
local pulse_time = 1
local pulse_base = 0.75 -- How much of the full overlay is contributed by the base health (the rest is added by the pulse)

HUD.DamageOverlayMaterial = Material("materials/nzombies-unlimited/hud/overlay_low_health.png", "unlitgeneric smooth")
function HUD:DamageOverlay()
	local ply = LocalPlayer() -- TODO: When spectating exists, replace this with view target
	local health = ply:Health()
	local max = ply:GetMaxHealth()

	local pct = health/max
	if pct < min_threshold then
		local fade = (pct < max_threshold and 1 or 1 - (pct - max_threshold)/(min_threshold - max_threshold))*pulse_base

		if pct < pulse_threshold then
			local pulse = 1 - (CurTime()%pulse_time)/pulse_time
			fade = fade + pulse*(1-pulse_base)
		end

		surface.SetMaterial(self.DamageOverlayMaterial)
		surface.SetDrawColor(255,0,0,255*fade)
		surface.DrawTexturedRect(0,0,ScrW(),ScrH())
	end
end

--[[-------------------------------------------------------------------------
Weapons HUD
---------------------------------------------------------------------------]]
local defaultmat = Material("nzombies-unlimited/hud/mk3a2_icon.png", "unlitgeneric smooth") -- TODO: Change this to not use old nZ material
local col_keybind = Color(255,255,100)
local col_noammo = Color(255,100,100)
local color_white = color_white

local weaponfont_secondary = "nzu_Font_Bloody_Medium"
local weaponfont_secondary_reserve = "nzu_Font_Bloody_Small"
local weaponfont_primary = "nzu_Font_Bloody_Huge"
local weaponfont_primary_reserve = "nzu_Font_Bloody_Medium"
local weaponfont_name = "nzu_Font_Bloody_Medium"

local equipmentfont = "nzu_Font_Bloody_Small"

function HUD:Weapons()
	local ply = LocalPlayer() -- TODO: Update to spectator when implemented

	local w,h = ScrW(),ScrH()

	local nameposh = h - 185
	local nameh = 100

	surface.SetMaterial(point_shadow)
	surface.SetDrawColor(0,0,0,255)

	for i = 1,2 do
		surface.DrawTexturedRect(w - 190, nameposh, 85, nameh)
		surface.DrawTexturedRectUV(w - 375, nameposh, 110, nameh, 1,0,0,1)
	end

	surface.DrawTexturedRectUV(w - 800, h - 130, 600, 45, 1,0,0,1)

	surface.SetMaterial(point_glow)

	--surface.SetDrawColor(255,255,255,255)
	-- Set to player's color instead?
	local v = ply:GetPlayerColor()
	surface.SetDrawColor(v.x*200 + 55, v.y*200 + 55, v.z*200 + 55,255)

	surface.DrawTexturedRect(w - 190, nameposh, 75, nameh)
	surface.DrawTexturedRectUV(w - 365, nameposh, 100, nameh, 1,0,0,1)

	surface.SetMaterial(point_shadow)
	surface.SetDrawColor(0,0,0,255)
	surface.DrawRect(w-250, nameposh, 40, nameh)
	for i = 1,2 do
		surface.DrawTexturedRect(w - 210, nameposh, 75, nameh)
		surface.DrawTexturedRectUV(w - 325, nameposh, 75, nameh, 1,0,0,1)
	end

	surface.DrawTexturedRectUV(w - 375, h - 130, 110, 45, 1,0,0,1)

	-- Draw the ammo for the weapon
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) then
		local primary = wep:GetPrimaryAmmoType()
		local secondary = wep:GetSecondaryAmmoType()

		local y1 = nameposh + nameh/2 + 20
		local x = w - 235
		local y = y1

		if secondary >= 0 then
			y = y - 12

			local clip2 = wep:Clip2()
			if clip2 >= 0 then
				local y2 = y - 5
				draw.SimpleText(clip2,weaponfont_secondary,x,y2,color_white,TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
				draw.SimpleText("/"..ply:GetAmmoCount(secondary),weaponfont_secondary_reserve,x,y2,color_white,TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			else
				draw.SimpleText(ply:GetAmmoCount(secondary),weaponfont_secondary,x,y - 5,color_white,TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end
		end

		if primary >= 0 then
			local clip = wep:Clip1()
			if clip >= 0 then
				draw.SimpleText(clip,weaponfont_primary,x,y,color_white,TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("/"..ply:GetAmmoCount(primary),weaponfont_primary_reserve,x,y,color_white,TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			else
				draw.SimpleText(ply:GetAmmoCount(primary),weaponfont_primary,x,y,color_white,TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			end					
		end

		draw.SimpleTextOutlined(wep:GetPrintName(),weaponfont_name,w - 320,y1 - 12,color_white,TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM,2,color_black)
	end

	local x = w - 390
	local y = h - 122
	local iconsize = 30

	for k,v in pairs(ply.nzu_HUDWeapons) do
		local wep = v.Weapon
		if IsValid(wep) then
			local todrawammo = true
			local shift = 0
			if type(wep.DrawHUDIcon) == "function" then
				shift,todrawammo = wep:DrawHUDIcon(x,y,iconsize)
			else --elseif wep.HUDIcon then DEBUG
				surface.SetMaterial(wep.HUDIcon or defaultmat)
				surface.SetDrawColor(255,255,255,255)
				surface.DrawTexturedRect(x - iconsize,y,iconsize,iconsize)

				shift = iconsize
			end

			if todrawammo then
				local count = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
				draw.SimpleTextOutlined("x"..count,equipmentfont,x - 5,y + iconsize,count > 0 and color_white or col_noammo,TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 2, color_black)
			end

			x = x - shift
			if v.Bind then
				draw.SimpleText(v.Bind,equipmentfont,x + 5,y + iconsize - 5,col_keybind,TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
			x = x - 50
		end
	end
end

--[[-------------------------------------------------------------------------
Downed Indicator
---------------------------------------------------------------------------]]
local REVIVEfont = "nzu_Font_Revive"
local downedindicator = Vector(0,0,25)
local point = Material("gui/point.png")
local revivetext = translate.Get("revive")
local revivebarheight = 10
local outlines = 5
local waveheight = 40
local pointheight = 15

function HUD:Draw_DownedIndicator(ply, revivor)
	local pos = (ply:GetPos() + downedindicator):ToScreen()
	if pos.visible then
		local x,y = pos.x,pos.y
		surface.SetFont(REVIVEfont)
		local w,h = surface.GetTextSize(revivetext)

		local w2 = w + outlines*2
		local x2 = x - w/2 - outlines
		local y2 = y - 6

		surface.SetMaterial(mat)
		surface.SetDrawColor(0,0,0,255)
		surface.DrawTexturedRectRotated(x, y - h, waveheight, w2, 90)

		surface.DrawRect(x2, y2, w2, revivebarheight)

		surface.SetMaterial(point)
		surface.DrawTexturedRect(x2, y2 + revivebarheight, w2, pointheight)
		

		if IsValid(revivor) then
			local diff = revivor.nzu_ReviveTime - revivor.nzu_ReviveStartTime
			local pct = (CurTime() - revivor.nzu_ReviveStartTime)/diff

			surface.SetDrawColor(255,255,255)
			surface.SetTextColor(255,255,255)
			surface.DrawRect(x2 + 4, y2 + 3, (w2 - 8) * pct, revivebarheight - 6)
		elseif ply.nzu_DownedTime then
			local pct = (1 - (CurTime() - ply.nzu_DownedTime)/bleedouttime)*255
			surface.SetDrawColor(255,pct,0)
			surface.SetTextColor(255,pct,0)
			surface.DrawRect(x2 + 4, y2 + 3, w2 - 8, revivebarheight - 6)
		end
		surface.DrawTexturedRect(x2 + 7, y2 + revivebarheight, w2 - 14, pointheight - 4)
		surface.SetMaterial(mat2)
		surface.DrawTexturedRectRotated(x, y - h, waveheight, w2, 90)
		
		surface.SetTextPos(pos.x - w/2, pos.y - h)
		surface.DrawText(revivetext)
	end
end

--[[-------------------------------------------------------------------------
Revive Progress
---------------------------------------------------------------------------]]
function HUD:Draw_ReviveProgress(ply, isbeingrevived)
	local lp = LocalPlayer()
	local w,h = ScrW()/2 ,ScrH()
	local revivor = isbeingrevived and ply or LocalPlayer()

	local diff = revivor.nzu_ReviveTime - revivor.nzu_ReviveStartTime
	local pct = (CurTime() - revivor.nzu_ReviveStartTime)/diff
	if pct > 1 then pct = 1 end

	surface.SetDrawColor(0,0,0)
	surface.DrawRect(w - 150, h - 300, 300, 20)

	surface.SetDrawColor(255,255,255)
	surface.DrawRect(w - 145, h - 295, 290*pct, 10)

	if isbeingrevived then
		draw.SimpleTextOutlined(translate.Get("being_revived_by").." "..ply:Nick(), "DermaLarge", w, h - 310, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
	else
		draw.SimpleTextOutlined(translate.Get("reviving").." "..ply:Nick(), "DermaLarge", w, h - 310, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
	end
end

--[[-------------------------------------------------------------------------
Target ID
---------------------------------------------------------------------------]]
local targetidfont = "nzu_Font_TargetID"

local typeformats = {
	[TARGETID_TYPE_USE] = function(text, data, ent) return translate.Get("press_e_to")..text end,
	[TARGETID_TYPE_BUY] = function(text, data, ent) return translate.Get("press_e_to_buy")..text..translate.Get("for").." "..data end,
	[TARGETID_TYPE_USECOST] = function(text, data, ent)
		return "Press E to"..text.."for "..data
	end,
	[TARGETID_TYPE_PLAYER] = function(text, data, ent) return ent:Nick() end,
	[TARGETID_TYPE_ELECTRICITY] = function(text) return text end,
}

function HUD:Draw_TargetID(text, typ, data, ent)
	local x,y = ScrW()/2, ScrH()/2 + 100
	local str = typeformats[typ] and typeformats[typ](text, data, ent) or text

	if str then
		draw.SimpleText(str, targetidfont, x, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end