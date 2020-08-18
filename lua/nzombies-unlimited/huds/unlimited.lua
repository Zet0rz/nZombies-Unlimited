
--[[-------------------------------------------------------------------------
Unlimited HUD - by Zet0r
A HUD based on the layout of BO3 Zombies, with its own custom theme
This is the built-in default HUD of nZombies Unlimited. You can make your own HUD similar to this.

You can make your own HUD by making a .lua file and putting it in "lua/nzombies-unlimited/huds/" just like this one.
The file should create its own HUD object (table) and return it at the end of the file.
You may add functions to this table exactly like you would a SWEP or ENT class file. However the prefix of the function name
determines the behavior of the function. These are the following behavior types:

	Paint_:
		This function is drawn in GM:HUDPaint(). Do this for all basic drawing functions.

		Example:
			function HUD:Paint_Round()
				surface.DrawText(nzu.Round:GetRound())
			end

	Panel_:
		This function creates a panel and returns it. It is run on HUD initialization.
		Do this if you want to use panels for your HUD. Panels can later be accessed in
		HUD.Panels.key where "key" is the what comes after "Panel_" in the name.

		Example:
			function HUD:Panel_Round()
				local p = vgui.Create("DLabel")
				p:ParentToHUD()
				p:SetPos(0,0)
				p:SetText(nzu.Round:GetRound())

				return p
			end

			(Panel can be reached in HUD.Panels.Round while it exists)

	Hook_:
		This function is a hook that will be hooked only while the HUD is active.
		The hook it hooks to is whatever comes after "Hook_" in the name.
		Do this if you want your HUD to react to certain events, such as to trigger Max Ammo or powerup alerts.

		Example:
			function HUD:Hook_Think()
				-- This is run on Think!
			end

	Initialize_:
		This function is run whenever the HUD is enabled, or re-enabled after every disable (unspawning and rejoining).
		This can be used to initialize local variables based on current game state that might have happened before the HUD hooks were active.
		Good with Hook_ functions to grab the correct "starting" state and using the hook to update it from here on.

		Example:
			function HUD:Initialize_GameState()
				-- This is run when the HUD activate!
			end


	Additionally!
	These values in the HUD have special meaning:
	- HUD.Player: The player currently viewing from (spectating, or local player)
	- HUD:OnPlayerChanged(new): If this exists, run whenever the observed player changes
	- HUD:IsValid(): Returns true while the HUD is active
	- HUD.Panels: The table of all panels created from Panel_ functions
	- HUD:GameOverPanel(): Creates the panel shown at game over

To make it simple, you can use this HUD as a boiler plate for developing your own.
Here is a table of contents of what components this HUD is made up from:

	- Round Indicator (Paint)
	- Points (Panel)
	- Damage Overlay (Health, Paint)
	- Weapons (Paint)
	- Downed Indicator (Paint)
	- Revive Progress (Paint)
	- Bleedout Greyscale Effects (Hook, RenderScreenspaceEffects)
	- Target ID (Special Functions)
	- Spectate Info (Panel + Special Function)
	- Powerups (Paint + Initialize + Special Function (alerts))
---------------------------------------------------------------------------]]

local HUD = {}

-------------------------
-- Localize
local pairs = pairs
local IsValid = IsValid
local math = math
local surface = surface
local table = table
-------------------------


--[[-------------------------------------------------------------------------
ROUND INDICATOR

Draws tally marks while the round is <=5, and text when higher.
When the round changes, this animates with a "burn-in" effect.
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

-- Localize for optimization
local ROUND = nzu.Round
local ROUND_PREPARING = ROUND_PREPARING
--

function HUD:Paint_Round()
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
			local x,y = surface.GetTextSize("Round")
			surface.SetTextPos(ScrW()/2 - x/2, ScrH()/2 - y)
			surface.DrawText("Round")

			surface.SetMaterial(tallymats[1])
			--surface.DrawTexturedRectUV(75, ScrH() - 175, tallysize, invpct2*tallysize, 0,0,1, invpct2)
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
POINTS

Creates a panel that automatically attaches players to itself, stacking player
panels on top of each other. These each have playermodel icons.
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

--[[-------------------------------------------------------------------------
DAMAGE OVERLAY

Draws the health of the player as an overlay on their screen.
Uses HUDPaintBackground to draw behind all other HUD.
---------------------------------------------------------------------------]]
local min_threshold = 0.7
local max_threshold = 0.3
local pulse_threshold = 0.4
local pulse_time = 1
local pulse_base = 0.75 -- How much of the full overlay is contributed by the base health (the rest is added by the pulse)

local damage_overlay = Material("materials/nzombies-unlimited/hud/overlay_low_health.png", "unlitgeneric smooth")

function HUD:Hook_HUDPaintBackground()
	local ply = self.Player
	local health = ply:Health()
	local max = ply:GetMaxHealth()

	local pct = health/max
	if pct < min_threshold then
		local fade = (pct < max_threshold and 1 or 1 - (pct - max_threshold)/(min_threshold - max_threshold))*pulse_base

		if pct < pulse_threshold then
			local pulse = 1 - (CurTime()%pulse_time)/pulse_time
			fade = fade + pulse*(1-pulse_base)
		end

		surface.SetMaterial(damage_overlay)
		surface.SetDrawColor(255,0,0,255*fade)
		surface.DrawTexturedRect(0,0,ScrW(),ScrH())
	end
end

--[[-------------------------------------------------------------------------
WEAPONS HUD

Draws the weapons the player is currently holding. Also responsible for drawing
the special slot weapons that have access through special keys.
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

--[[-------------------------------------------------------------------------
hudweapons table

The functions structured in the following section keep track of all weapons the player
is notified of receiving. Whenever a weapon's slot has a keybind to it, it will
be added to the hudweapons table. This table then contains the ordered set
of accessible weapons.

You can copy/paste this if you want a dynamic drawing of keybinds independent of slots
---------------------------------------------------------------------------]]
local hudweapons

function HUD:Initialize_KeybindSlots()
	hudweapons = {}
	for k,v in pairs(LocalPlayer():GetWeaponSlots()) do
		if IsValid(v.Weapon) then
			local keybind = nzu.GetKeybindForWeaponSlot(k)
			if keybind then
				table.insert(hudweapons, {Weapon = v.Weapon, Bind = input.GetKeyName(keybind)})
			end
		end
	end
end

function HUD:Hook_nzu_WeaponEquippedInSlot(ply, wep, slot)
	local keybind = nzu.GetKeybindForWeaponSlot(slot)
	if keybind then
		table.insert(hudweapons, {Weapon = wep, Bind = input.GetKeyName(keybind)})
	end
end

function HUD:Hook_nzu_WeaponRemovedFromSlot(ply, wep, slot)
	for k,v in pairs(hudweapons) do
		if v.Weapon == wep then
			table.remove(hudweapons, k)
			return
		end
	end
end

--[[-------------------------------------------------------------------------
Painting the HUD
---------------------------------------------------------------------------]]
function HUD:Paint_Weapons()
	local ply = self.Player
	local w,h = ScrW(),ScrH()

	local nameposh = h - 185
	local nameh = 100

	surface.SetMaterial(point_shadow)
	surface.SetDrawColor(0,0,0,255)

	for i = 1,2 do
		surface.DrawTexturedRect(w - 150, nameposh, 85, nameh)
		surface.DrawTexturedRectUV(w - 335, nameposh, 110, nameh, 1,0,0,1)
	end

	surface.DrawTexturedRectUV(w - 760, h - 130, 600, 45, 1,0,0,1)

	surface.SetMaterial(point_glow)

	--surface.SetDrawColor(255,255,255,255)
	-- Set to player's color instead?
	local v = ply:GetPlayerColor()
	surface.SetDrawColor(v.x*200 + 55, v.y*200 + 55, v.z*200 + 55,255)

	surface.DrawTexturedRect(w - 150, nameposh, 75, nameh)
	surface.DrawTexturedRectUV(w - 325, nameposh, 100, nameh, 1,0,0,1)

	surface.SetMaterial(point_shadow)
	surface.SetDrawColor(0,0,0,255)
	surface.DrawRect(w-210, nameposh, 40, nameh)
	for i = 1,2 do
		surface.DrawTexturedRect(w - 170, nameposh, 75, nameh)
		surface.DrawTexturedRectUV(w - 285, nameposh, 75, nameh, 1,0,0,1)
	end

	surface.DrawTexturedRectUV(w - 335, h - 130, 110, 45, 1,0,0,1)

	-- Draw the ammo for the weapon
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) then
		local primary = wep:GetPrimaryAmmoType()
		local secondary = wep:GetSecondaryAmmoType()

		local y1 = nameposh + nameh/2 + 20
		local x = w - 195
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
				if clip >= 100 then x = x + 15 end
				draw.SimpleText(clip,weaponfont_primary,x,y,color_white,TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
				draw.SimpleText("/"..ply:GetAmmoCount(primary),weaponfont_primary_reserve,x,y,color_white,TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			else
				draw.SimpleText(ply:GetAmmoCount(primary),weaponfont_primary,x,y,color_white,TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			end					
		end

		draw.SimpleTextOutlined(wep:GetPrintName(),weaponfont_name,w - 280,y1 - 12,color_white,TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM,2,color_black)
	end

	local x = w - 350
	local y = h - 122
	local iconsize = 30

	for k,v in pairs(hudweapons) do
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
				local count = wep:Ammo1()
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
DOWNED INDICATOR

Draws the icon to revive players above every downed other player.
This is split into two functions: One draws a single indicator, the other
loops through all downed players and runs the first function for each of them
---------------------------------------------------------------------------]]
local REVIVEfont = "nzu_Font_Revive"
local downedindicator = Vector(0,0,25)
local point = Material("gui/point.png")
local revivetext = "REVIVE"
local revivebarheight = 10
local outlines = 5
local waveheight = 40
local pointheight = 15
local bleedouttime = 45

-- This table contains the keys of all downed players, and the value of their fastest revivor
-- The value is NULL (not nil) if there is no revivor but they are downed
local downedplayers = nzu.GetDownedPlayersRevivors()

function HUD:Paint_DownedIndicators()
	for k,v in pairs(downedplayers) do
		if k ~= self.Player then -- We don't draw this for our observed player
			local pos = (ply:GetPos() + downedindicator):ToScreen()
			if pos.visible then
				local x,y = pos.x,pos.y

				surface.SetFont(REVIVEfont)
				local w,h = surface.GetTextSize(revivetext)

				local w2 = w + outlines*2
				local x2 = x - w/2 - outlines
				local y2 = y - 6

				surface.SetMaterial(point_shadow)
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
				surface.SetMaterial(point_glow)
				surface.DrawTexturedRectRotated(x, y - h, waveheight, w2, 90)
				
				surface.SetTextPos(x - w/2, y - h)
				surface.DrawText(revivetext)
			end
		end
	end
end

--[[-------------------------------------------------------------------------
REVIVE PROGRESS

The progress bar for reviving a player. This uses the "downedplayers" table above
to check if the observed player has a revivor. Otherwise, it checks the observed player's
revive target
---------------------------------------------------------------------------]]
function HUD:Paint_ReviveProgress(_, ply, isbeingrevived)
	local ply = downedplayers[self.Player] -- Starts off as who is reviving us
	local isbeingrevived = true
	local anyprogress = IsValid(revivor)

	if not anyprogress then
		ply = self.Player.nzu_ReviveTarget -- Otherwise whoever we're reviving
		if IsValid(revivor) then
			isbeingrevived = false -- This isn't us being revived
			anyprogress = true
		end
	end

	if anyprogress then
		local w,h = ScrW()/2, ScrH()
		local revivor = isbeingrevived and ply or self.Player

		local diff = revivor.nzu_ReviveTime - revivor.nzu_ReviveStartTime
		local pct = (CurTime() - revivor.nzu_ReviveStartTime)/diff
		if pct > 1 then pct = 1 end

		surface.SetDrawColor(0,0,0)
		surface.DrawRect(w - 150, h - 300, 300, 20)

		surface.SetDrawColor(255,255,255)
		surface.DrawRect(w - 145, h - 295, 290*pct, 10)

		if isbeingrevived then
			draw.SimpleTextOutlined("Being revived by "..ply:Nick(), "DermaLarge", w, h - 310, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
		else
			draw.SimpleTextOutlined("Reviving "..ply:Nick(), "DermaLarge", w, h - 310, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
		end
	end	
end

--[[-------------------------------------------------------------------------
BLEED OUT COLOR DISTORTION

This is hooked to RenderScreenspaceEffects. It draws the color modifications for
the bleedout time left. Remember that HUDs can only have 1 hook for each hook type,
so if you wish to use more screenspace effects, put them all into 1 function (perhaps categorize in multiple local functions)
---------------------------------------------------------------------------]]
local colmod = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}
function HUD:Hook_RenderScreenspaceEffects() -- Deathtime will be added later when variable down times is supported and networked
	local ply = self.Player
	if ply:GetIsDowned() then

		local diff = ply.nzu_BleedoutTime - ply.nzu_DownedTime
		local pct = (CurTime() - ply.nzu_DownedTime)/diff

		colmod["$pp_colour_colour"] = 1 - pct
		colmod["$pp_colour_addr"] = pct*0.5
		DrawColorModify(colmod)
	end
end

--[[-------------------------------------------------------------------------
Target ID

This uses special functions called directly from the HUD Management file.
DrawTargetID() is called whenever there is generic text ready to draw.
DrawTargetID[type]() is called whenever an entity returns a specific formatting type.
If the HUD does not implement this type, the gamemode attempts to translate it (using hook nzu_TranslateTargetID)
and the formatted text is drawn in generic DrawTargetID().

HUD:DrawTargetID() must be implemented to have any Target ID functionality (the gamemode will not perform any of these actions if the hud does not have the generic function)
---------------------------------------------------------------------------]]
local targetidfont = "nzu_Font_TargetID"

-- Special Function: DrawTargetID is called with the text whenever it is a generic type that should just be shown
-- Additionally, if it was translated from a type, these are also passed in the following format:
-- (str, type, oldstr, ent, val)

-- str: The formatted text (just draw this directly)
-- type: The type it was formatted from
-- oldstr: The string that was used in the formatting (in case you want to format your own and ignore built-in, but you kinda shouldn't)
-- ent: The entity this was translated from
-- val: The additional data value used in the translation (often price when used with "Buy" type)

function HUD:DrawTargetID(str)
	local x,y = ScrW()/2, ScrH()/2 + 100
	draw.SimpleText(str, targetidfont, x, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Special Target ID type-based functions. These receive input strings and let you format your own
-- Alternatively you can even draw entirely different based on type (such as adding icons).
-- In this HUD, it just formats the text and runs the generic one with it

-- These are the base gamemode ones: Use, UseCost, Buy, Player, NoElectricity
function HUD:DrawTargetIDUse(str, ent, val)
	self:DrawTargetID("Press E to "..str)
end

function HUD:DrawTargetIDUseCost(str, ent, val)
	self:DrawTargetID("Press E to "..str.." for "..val)
end

function HUD:DrawTargetIDBuy(str, ent, val)
	self:DrawTargetID("Press E to buy "..str.." for "..val)
end

function HUD:DrawTargetIDPlayer(str, ent, val)
	self:DrawTargetID(str) -- For Player formats, the string is the name of the player
end

function HUD:DrawTargetIDNoElectricity(str, ent, val)
	self:DrawTargetID("Requires Electricity")
end

function HUD:DrawTargetIDPickUp(str, ent, val)
	self:DrawTargetID("Press E to pick up "..str)
end

-- For weapons, the value is the weapon class. We just use Pick Up formatting though
HUD.DrawTargetIDWeapon = HUD.DrawTargetIDPickUp

--[[-------------------------------------------------------------------------
Spectate Info

A panel that shows the currently spectated player
It is hidden whenever the player is LocalPlayer()
HUD:OnPlayerChanged runs when the player changes, and shows/hides the panel accordingly
---------------------------------------------------------------------------]]
local spectate_name_font = "nzu_Font_Bloody_Medium"

--[[function HUD:Paint_SpectateInfo()
	local ply = self.Player
	local x,y = ScrW() / 2, ScrH() - 100

	surface.SetMaterial(point_glow)
	local v = ply:GetPlayerColor()
	surface.SetDrawColor(v.x*200 + 55, v.y*200 + 55, v.z*200 + 55,255)

	surface.DrawTexturedRect(x - 150, y, 75, 50)
	surface.DrawTexturedRectUV(x - 325, y, 100, 50, 1,0,0,1)

	surface.SetMaterial(point_shadow)
	surface.SetDrawColor(0,0,0,255)
	surface.DrawRect(x-210, y, 40, 50)

	draw.SimpleText(ply:Nick(), spectate_name_font, x, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end]]

function HUD:Panel_SpectateInfo()
	local pnl = vgui.Create("DPanel")
	pnl:ParentToHUD()
	pnl:SetSize(400,50)
	pnl:SetPos(ScrW()/2 - pnl:GetWide()/2, ScrH() - 100)
	pnl:SetBackgroundColor(Color(0,0,0,200))

	local mid = pnl:Add("Panel")
	mid:Dock(FILL)

	local spectate = mid:Add("DLabel")
	spectate:SetText("Spectating")
	spectate:Dock(TOP)
	spectate:SetContentAlignment(5)
	spectate:SizeToContentsY()
	spectate:DockMargin(0,5,0,0)

	local ply = mid:Add("DLabel")
	ply:SetFont("Trebuchet24")
	ply:SetText(self.Player:Nick())
	ply:Dock(FILL)
	ply:SetContentAlignment(8)

	local spec_next = pnl:Add("Panel")
	spec_next:Dock(RIGHT)
	spec_next:SetWide(50)
	local spec_next_icon = spec_next:Add("DLabel")
	spec_next_icon:SetText(">")
	spec_next_icon:SetFont("DermaLarge")
	spec_next_icon:Dock(FILL)
	spec_next_icon:SetContentAlignment(5)
	local spec_next_text = spec_next:Add("DLabel")
	spec_next_text:SetText("RMB")
	spec_next_text:Dock(BOTTOM)
	spec_next_text:SetContentAlignment(5)

	local spec_prev = pnl:Add("Panel")
	spec_prev:Dock(LEFT)
	spec_prev:SetWide(50)
	local spec_prev_icon = spec_prev:Add("DLabel")
	spec_prev_icon:SetText("<")
	spec_prev_icon:SetFont("DermaLarge")
	spec_prev_icon:Dock(FILL)
	spec_prev_icon:SetContentAlignment(5)
	local spec_prev_text = spec_prev:Add("DLabel")
	spec_prev_text:SetText(" LMB")
	spec_prev_text:Dock(BOTTOM)
	spec_prev_text:SetContentAlignment(5)

	function pnl:SetPlayer(pl)
		ply:SetText(pl:Nick())
	end

	if self.Player == LocalPlayer() then
		pnl:Hide()
	end

	return pnl
end

function HUD:OnPlayerChanged(ply)
	if ply == LocalPlayer() then
		self.Panels.SpectateInfo:Hide()
	else
		self.Panels.SpectateInfo:Show()
		self.Panels.SpectateInfo:SetPlayer(ply)
	end
end

--[[-------------------------------------------------------------------------
Powerups

This demonstrates a method of capturing Powerup activations and keeping an order
It hooks into powerup activation, both personal and global,
and creates icons if there isn't one already, and adds it to an ordered table
where it is trivial to paint them in that order

Global and Personal powerups are tracked independently (but still retain order)
They could potentially be merged, if you want in your own HUD
---------------------------------------------------------------------------]]
local activepowerups
--local numpowerups

-- Initialize the tables; Add all active powerups to the Activepowerups table, and add their position as lookup in the order table
function HUD:Initialize_Powerups()
	activepowerups = {}
	--numpowerups = 0

	for k,v in pairs(nzu.GetGlobalActivePowerups()) do
		local neg,id = nzu.IsNegativePowerup(k)
		local powerup = nzu.GetPowerup(id)
		table.insert(activepowerups, {ID = id, Negative = neg, EndTime = v, Icon = powerup and powerup.Icon})
		--numpowerups = numpowerups + 1
	end

	-- We could use self.Player, but since powerups are only networked to their owner, we just use LocalPlayer() regardless of who we're spectating
	for k,v in pairs(LocalPlayer():GetPersonalActivePowerups()) do
		local neg,id = nzu.IsNegativePowerup(k)
		local powerup = nzu.GetPowerup(id)
		table.insert(activepowerups, {ID = id, Negative = neg, EndTime = v, Personal = true, Icon = powerup and powerup.Icon})
		--numpowerups = numpowerups + 1
	end
end

local iconsize = 80
local bgsize = 100
local icondist = 102
local bg_green = Material("nzombies-unlimited/hud/powerups/background_unlimited-green.png", "unlitgeneric smooth")
local bg_blue = Material("nzombies-unlimited/hud/powerups/background_unlimited-blue.png", "unlitgeneric smooth")
local bg_red = Material("nzombies-unlimited/hud/powerups/background_unlimited-red.png", "unlitgeneric smooth")
local bg_purple = Material("nzombies-unlimited/hud/powerups/background_unlimited-purple.png", "unlitgeneric smooth")

-- This function basically steals the algorithm from draw.SimpleTextOutlined to draw an outlined textured rect
-- It works by drawing the icon multiple times in every direction behind the main icon to give it an outline-like effect
local function DrawTexturedRectOutline(x,y,w,h,width)
	local steps = ( width * 2 ) / 3
	if ( steps < 1 ) then steps = 1 end

	for _x = -width, width, steps do
		for _y = -width, width, steps do
			surface.DrawTexturedRect(x + _x, y + _y, w,h)
		end
	end
end

--local activepowerups = {{Icon = Material("nzombies-unlimited/hud/powerups/deathmachine.png", "unlitgeneric smooth")}, {Icon = Material("nzombies-unlimited/hud/powerups/instakill.png", "unlitgeneric smooth")}, {Icon = Material("nzombies-unlimited/hud/powerups/doublepoints.png", "unlitgeneric smooth")}, {Icon = Material("nzombies-unlimited/hud/powerups/firesale.png", "unlitgeneric smooth")}, {Icon = Material("nzombies-unlimited/hud/powerups/bonfiresale.png", "unlitgeneric smooth")}}
function HUD:Paint_Powerups()
	local num = #activepowerups + 2
	local icondiff = (bgsize - iconsize)/2

	local ct = CurTime()
	for k,v in pairs(activepowerups) do
		local timeleft = v.EndTime and v.EndTime - ct

		if not timeleft or timeleft > 10 or (timeleft > 3 and timeleft % 1 > 0.5) or (timeleft <= 3 and timeleft % 0.5 > 0.25) then
			surface.SetMaterial(v.Negative and (v.Personal and bg_purple or bg_red) or (v.Personal and bg_blue or bg_green))
			surface.SetDrawColor(255,255,255)

			local xpos = (ScrW() - icondist*num)/2 + icondist*k
			local ypos = ScrH() - 250
			surface.DrawTexturedRect(xpos, ypos, bgsize, bgsize)

			local xpos2 = xpos + icondiff
			local ypos2 = ypos + icondiff - 5
			surface.SetMaterial(v.Icon)
			surface.SetDrawColor(0,0,0)
			DrawTexturedRectOutline(xpos2, ypos2, iconsize, iconsize,4)
			--surface.DrawTexturedRect(xpos2 + 5, ypos2 + 2, iconsize, iconsize,5)
			surface.SetDrawColor(255,255,255)
			surface.DrawTexturedRect(xpos2, ypos2, iconsize, iconsize,5)
		end
	end
end

-- Whenever a powerup is activated, loop through all icons and update the time of the one equivalent to this, if so
-- If the loop is exited without finding this, add it as a new icon to the table
function HUD:Hook_nzu_PowerupActivated(id, neg, dur, ply)
	if not ply or ply == LocalPlayer() then
		local powerup = nzu.GetPowerup(id)

		if dur and (not powerup or powerup.Duration) then
			local isply = ply and true or nil
			for k,v in pairs(activepowerups) do
				if v.ID == id and v.Negative == neg and v.Personal == isply then
					local newtime = CurTime() + dur
					if v.EndTime < newtime then v.EndTime = newtime end
					return
				end
			end

			table.insert(activepowerups, {ID = id, Negative = neg, EndTime = CurTime() + dur, Personal = ply and true or nil, Icon = powerup and powerup.Icon})
			--numpowerups = numpowerups + 1
		else
			self:Alert(powerup and powerup.Name or id)
		end
	end
end
HUD.Hook_nzu_PowerupActivated_Personal = HUD.Hook_nzu_PowerupActivated -- This is the same function :D

-- Loop through all icons and remove the one that is equivalent. This reorders all icons beneath it too.
function HUD:Hook_nzu_PowerupEnded(id, neg, ply)
	if not ply or ply == LocalPlayer() then
		local isply = ply and true or nil
		for k,v in pairs(activepowerups) do
			if v.ID == id and v.Negative == neg and v.Personal == isply then
				table.remove(activepowerups, k)
				--numpowerups = numpowerups - 1
				return
			end
		end
	end
end

-- All these hooks are the same; regardless of how a powerup ends, we remove it
HUD.Hook_nzu_PowerupEnded_Personal = HUD.Hook_nzu_PowerupEnded
HUD.Hook_nzu_PowerupTerminated = HUD.Hook_nzu_PowerupEnded
HUD.Hook_nzu_PowerupTerminated_Personal = HUD.Hook_nzu_PowerupEnded

--[[-------------------------------------------------------------------------
Alerts!
We use these for powerups that don't have an activation time, but it can
also be used by the gamemode to display any text (very rare circumstances)
---------------------------------------------------------------------------]]
-- Also coincidentally the same one used by powerup drop glows
local circleglow = Material("nzombies-unlimited/particle/powerup_glow_09")
-- Font = weaponfont_primary

function HUD:Alert(text)
	if self.Panels.Alert then
		self.Panels.Alert:SetText(text)
	else
		local p = vgui.Create("Panel")
		p:ParentToHUD()
		p:SetSize(800, 300)
		p.NextParticle = 0
		p.Particles = {}

		local nextparticleindex = 1
		local maxparticles = 6
		local particledur = 2

		function p:Paint(w,h)
			local w_h = w/2
			local line_height = 50
			local h_line = h - line_height
			local glowwidth = 250

			-- Rotating Glow Circle, starting with shadow
			if self.NextParticle < CurTime() then
				self.Particles[nextparticleindex] = {Rot = math.random(360), Time = CurTime() + particledur/2}
				self.NextParticle = CurTime() + particledur/maxparticles
				nextparticleindex = (nextparticleindex % maxparticles) + 1
			end

			local rot = 0
			local size = h_line*2.5
			local rot_h = h

			surface.SetMaterial(circleglow)
			for k,v in pairs(self.Particles) do
				surface.SetDrawColor(255,255,255,255 - math.abs(v.Time - CurTime()) * 255)
				surface.DrawTexturedRectRotated(w_h, rot_h, size, size, v.Rot)
			end

			--surface.SetMaterial(point_shadow)
			--surface.DrawTexturedRectRotated(w_h, h_line - 10, 30, glowwidth, 90)
			
			--[[surface.SetDrawColor(0,0,0,255)
			surface.SetMaterial(circleglow)
			surface.DrawTexturedRectRotated(w_h, rot_h, size, size, rot)

			-- Then the rotating glow
			surface.SetDrawColor(255,255,255,255)
			surface.DrawTexturedRectRotated(w_h, rot_h, size - 20, size - 20, rot)
			-- Then the overlaid rotating shadow
			surface.SetDrawColor(0,0,0,255)
			surface.DrawTexturedRectRotated(w_h, rot_h, size - 40, size - 40, rot)]]

			-- Central rectangle
			surface.SetDrawColor(0,0,0,255)
			surface.DrawRect(glowwidth, h_line, w - glowwidth*2, line_height)

			-- Outer glow shadow
			surface.SetMaterial(point_shadow)
			surface.DrawTexturedRect(w - glowwidth, h_line, glowwidth, line_height)
			surface.DrawTexturedRectUV(0, h_line, glowwidth, line_height, 1,0,0,1)

			-- Outer glow color
			surface.SetDrawColor(255,255,255,255)
			surface.SetMaterial(point_glow)
			surface.DrawTexturedRect(w - glowwidth, h_line, glowwidth, line_height)
			surface.DrawTexturedRectUV(0, h_line, glowwidth, line_height, 1,0,0,1)

			-- Outer glow shadow overlay
			local glowwidth2 = 100
			surface.SetDrawColor(0,0,0,255)
			surface.SetMaterial(point_shadow)
			surface.DrawTexturedRect(w - glowwidth, h_line, glowwidth - glowwidth2, line_height)
			surface.DrawTexturedRectUV(glowwidth2, h_line, glowwidth - glowwidth2, line_height, 1,0,0,1)

			draw.SimpleTextOutlined(self.Text, weaponfont_name, w_h, h_line + line_height/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
		end

		function p:Think()
			if self.RemoveTime and self.RemoveTime < CurTime() then
				self:AlphaTo(0,2,0, function()
					self:Remove()
				end)
				self.RemoveTime = nil
			end
		end

		function p:SetText(t)
			self.Text = t
			self:SetAlpha(0)
			self:AlphaTo(255, 0.25, 0)
			self.RemoveTime = CurTime() + 5
		end

		p:SetPos((ScrW() - p:GetWide())/2, 50)
		p:SetText(text)

		return p
	end
end


--[[-------------------------------------------------------------------------
Game Over Panel
This is actually an internal function, but it is called through the Scoreboard file
---------------------------------------------------------------------------]]
function HUD:GameOverPanel()
	local p = vgui.Create("Panel")
	local txt = p:Add("DLabel")
	txt:SetFont("nzu_Font_Bloody_Biggest")
	txt:SetTextColor(Color(150,0,0))
	txt:SetText("GAME OVER")
	txt:SetContentAlignment(5)
	txt:Dock(FILL)
	txt:DockMargin(0,0,0,-50)

	local r = p:Add("DLabel")
	r:SetFont("nzu_Font_Bloody_Large")
	r:SetText(nzu.Round:GetRound() == 1 and "You survived 1 round." or "You survived "..(nzu.Round:GetRound() or 0).." rounds.")
	r:SetTextColor(Color(150,0,0))
	r:SetContentAlignment(5)
	r:Dock(BOTTOM)
	r:SizeToContentsY()
	r:DockMargin(0,0,0,50)

	p:SetTall(250)
	p:SetWide(1000)

	return p
end

return HUD