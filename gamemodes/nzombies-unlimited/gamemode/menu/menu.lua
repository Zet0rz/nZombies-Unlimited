
if CLIENT then
	local SUBMENU = {}
	local textcolor = Color(220,220,220)
	local function drawcorneredbox(w,h,cornerthickness, cornerlength)
		surface.SetDrawColor(255,255,255, 30)
		surface.DrawRect(0,0,cornerlength, cornerthickness)
		surface.DrawRect(0,cornerthickness, cornerthickness, cornerlength - cornerthickness)

		surface.DrawRect(w - cornerlength,0,cornerlength, cornerthickness)
		surface.DrawRect(w - cornerthickness,cornerthickness, cornerthickness, cornerlength - cornerthickness)

		surface.DrawRect(0,h - cornerthickness,cornerlength, cornerthickness)
		surface.DrawRect(0,h - cornerlength, cornerthickness, cornerlength - cornerthickness)

		surface.DrawRect(w - cornerlength,h - cornerthickness,cornerlength, cornerthickness)
		surface.DrawRect(w - cornerthickness,h - cornerlength, cornerthickness, cornerlength - cornerthickness)
	end
	local paintfunc = function(b, w, h) -- Draw the black button with the white corners
		if b.AdminOnly and not nzu.IsAdmin(LocalPlayer()) then
			surface.SetDrawColor(50,25,25,230)
		else
			if b.Hovered then
				surface.SetDrawColor(50,50,50,240)
			else
				surface.SetDrawColor(0,0,0,220)
			end
		end
		b:DrawFilledRect()
		drawcorneredbox(w,h,3, 15)
	end
	local function buttondoclick(b)
		if not b.AdminOnly or nzu.IsAdmin(LocalPlayer()) then
			b:ClickFunction()
		end
	end
	local function generatebutton(text, admin, parent)
		local b = vgui.Create("DButton", parent)
		b:SetFont("DermaLarge")
		b:SetText(text) -- Append spaces around to free from edges
		b:SetTextColor(textcolor)
		b:SetContentAlignment(4)
		b:DockMargin(0,1,0,1)
		b:SetTall(50)
		b:SetTextInset(10,0)

		b.AdminOnly = admin
		if admin and not nzu.IsAdmin(LocalPlayer()) then b:SetDisabled(true) end

		--b.Paint = paintfunc
		b:SetSkin("nZombies Unlimited")
		b.DoClick = buttondoclick
		b:Dock(TOP)

		return b
	end
	function SUBMENU:AddButton(text, zpos, func, admin)
		if IsValid(self.Contents) then
			local b = generatebutton(text, admin, self.Contents)
			b:SetZPos(zpos)
			b.SubMenu = self
			b.ClickFunction = func
			self.Contents:Add(b)

			return b
		end
	end

	local function submenuclick(b)
		local s = b.SubMenu
		if IsValid(s) then
			local p = b.SubPanel
			if IsValid(p) then
				s:Hide()
				s:OnHid()
				p:OnShown()
				p:Show()
			end
		end
	end
	function SUBMENU:AddSubMenu(text, zpos, admin)
		if IsValid(self.Contents) then
			local b = generatebutton(text, admin, self.Contents)
			b:SetZPos(zpos)

			local submenu = vgui.Create("nzu_MenuPanel_SubMenu", self:GetParent())
			submenu:Dock(FILL)
			submenu.Menu = self.Menu

			b.SubMenu = self
			b.SubPanel = submenu
			submenu:SetPrevious(text, self)
			b.ClickFunction = submenuclick
			self.Contents:Add(b)

			return submenu, b
		end
	end
	function SUBMENU:AddPanel(text, zpos, panel, admin)
		if IsValid(self.Contents) then
			local b = generatebutton(text, admin, self.Contents)
			b:SetZPos(zpos)

			local submenu = vgui.Create("nzu_MenuPanel_SubMenu", self:GetParent())
			submenu:Dock(FILL)
			submenu:SetContents(panel)
			submenu.Menu = self.Menu

			b.SubMenu = self
			b.SubPanel = submenu
			submenu:SetPrevious(text, self)
			b.ClickFunction = submenuclick
			self.Contents:Add(b)

			return submenu, b
		end
	end

	function SUBMENU:Init()
		self.TopBar = self:Add("Panel")
		self.TopBar:Dock(TOP)
		self.TopBar:SetTall(40)

		self.BackButton = generatebutton(" < Back")
		self.BackButton:SetParent(self.TopBar)
		self.BackButton:SizeToContents()
		self.BackButton:Dock(LEFT)
		self.BackButton:SetContentAlignment(4)
		self.BackButton.DoClick = submenuclick
		self.BackButton.SubMenu = self
		self.BackButton:Hide()

		self.Contents = self:Add("DScrollPanel")
		self.Contents:SetPaintBackground(false)
		self.Contents:Dock(FILL)

		self:Hide()
	end
	function SUBMENU:SetPrevious(text, panel)
		if IsValid(panel) then
			self.BackButton:Show()
			self.BackButton:SetText("  < ".. text .. " ")
			self.BackButton:SizeToContents()
			self.BackButton.SubPanel = panel
			self.Previous = panel
		else
			self.BackButton:Hide()
		end
	end
	function SUBMENU:SetContents(panel)
		if IsValid(self.Contents) then self.Contents:Remove() end
		self.Contents = panel
		panel:SetParent(self)
		panel:Dock(FILL)
	end
	function SUBMENU:GetContents()
		return self.Contents
	end
	function SUBMENU:GetTopBar() return self.TopBar end

	function SUBMENU:OnShown() end
	function SUBMENU:OnHid() end
	vgui.Register("nzu_MenuPanel_SubMenu", SUBMENU, "Panel")

	local PLAYER_AVATAR = {}
	function PLAYER_AVATAR:Init()
		self.Icon = vgui.Create("ModelImage", self)
		self.Icon:SetMouseInputEnabled(false)
		self.Icon:SetKeyboardInputEnabled(false)
		self.Icon:Dock(FILL)

		self.R = 0
		self.G = 0
		self.B = 0
	end
	function PLAYER_AVATAR:SetPlayer(ply)
		self.Player = ply
		self.Model = ply:GetModel()

		self.Icon:SetModel(self.Model)
	end
	function PLAYER_AVATAR:Think()
		if IsValid(self.Player) then
			local mdl = self.Player:GetModel()
			if mdl ~= self.Model then
				self.Icon:SetModel(mdl)
				self.Model = mdl
			end

			local col = self.Player:GetPlayerColor()
			if col ~= self.PlayerColor then
				self.R = col.x * 150 + 100
				self.G = col.y * 150 + 100
				self.B = col.z * 150 + 100
				self.PlayerColor = col
			end
		end
	end
	local glowmat = Material("particle/particle_glow_04")
	function PLAYER_AVATAR:Paint(w,h)
		surface.SetDrawColor(0,0,0,200)
		self:DrawFilledRect()

		surface.SetDrawColor(self.R, self.G, self.B, 200)
		surface.SetMaterial(glowmat)
		surface.DrawTexturedRect(-10,-10,w+20,h+20)
	end
	vgui.Register("nzu_PlayerAvatar", PLAYER_AVATAR, "DPanel")

	local PLAYER_LINE = {}
	local talkcol = Color(255,150,0)
	local function barpaint(p,w,h)
		surface.SetDrawColor(0,0,0,220)
		surface.DrawRect(0,0,w,h)

		drawcorneredbox(w,h,4,20)
	end
	function PLAYER_LINE:Init()
		self:SetTall(64)
		self:DockMargin(0,0,0,1)

		self.Character = self:Add("nzu_PlayerAvatar")
		self.Character:SetSize(54,54)
		self.Character:DockMargin(5,5,15,5)
		self.Character:Dock(LEFT)

		self.Panel = self:Add("DPanel")
		self.Panel:DockPadding(10,10,10,10)
		self.Panel:Dock(FILL)
		self.Panel.m_bDrawCorners = true

		self.Avatar = self.Panel:Add("AvatarImage")
		self.Avatar:SetWide(44)
		self.Avatar:Dock(LEFT)

		self.Ping = self.Panel:Add("DLabel")
		self.Ping:Dock(RIGHT)
		self.Ping:SetFont("HudHintTextLarge")
		self.Ping:SetContentAlignment(5)
		--self.Ping:SetZPos(0)

		self.Mute = self.Panel:Add("DImageButton")
		self.Mute:SetSize(32, 32)
		self.Mute:DockMargin(0,6,0,6)
		self.Mute:Dock(RIGHT)
		self.Mute.Talking = false
		self.Mute.Think = function(s)
			if IsValid(self.Player) then
				if self.Player:IsVoiceAudible() ~= s.Talking then
					s.Talking = self.Player:IsVoiceAudible()
					s:SetColor(s.Talking and talkcol or color_white)
				end
			end
		end
		--self.Mute:SetZPos(1)

		self.Name = self.Panel:Add("DLabel")
		self.Name:SetText("")
		self.Name:DockMargin(10,0,10,0)
		self.Name:SetFont("DermaLarge")
		self.Name:Dock(FILL)
	end

	function PLAYER_LINE:Setup(ply)
		self.Player = ply
		if IsValid(self.Avatar) then self.Avatar:SetPlayer(ply, 64) end
		if IsValid(self.Character) then self.Character:SetPlayer(ply) end
		self:SetZPos(self.Player:EntIndex())

		self:Think()
	end

	local spawnedcolor = Color(20,30,60)
	function PLAYER_LINE:Think()
		if not IsValid(self.Player) then self:Remove() end

		if self.PName == nil or self.PName ~= self.Player:Nick() then
			self.PName = self.Player:Nick()
			self.Name:SetText(self.PName)
		end
		
		if self.NumPing == nil or self.NumPing ~= self.Player:Ping() then
			self.NumPing = self.Player:Ping()
			self.Ping:SetText(self.NumPing)
		end

		if self.Muted == nil or self.Muted ~= self.Player:IsMuted() then
			self.Muted = self.Player:IsMuted()
			self.Mute:SetImage(self.Muted and "icon32/muted.png" or "icon32/unmuted.png")
			self.Mute.DoClick = function() self.Player:SetMuted(not self.Muted) end
		end

		if self.IsReady == nil or self.IsReady ~= (self.Player:IsReady() or not self.Player:IsUnspawned()) then
			self.IsReady = self.Player:IsReady() or not self.Player:IsUnspawned()
			self.Panel:SetBackgroundColor(self.IsReady and spawnedcolor or nil)
		end
	end
	vgui.Register("nzu_MenuPanel_PlayerLine", PLAYER_LINE, "Panel")

	local PANEL = {}

	-- Important functions for you developers out there here at the top
	function PANEL:AddButton(text, zpos, func, admin)
		return self.MenuRoot:AddButton(text, zpos, func, admin)
	end

	function PANEL:AddSubMenu(text, zpos, admin)
		return self.MenuRoot:AddSubMenu(text, zpos, admin)
	end
	
	function PANEL:AddPanel(text, zpos, panel, admin)
		return self.MenuRoot:AddPanel(text, zpos, panel, admin)
	end
	
	--function PANEL:AddNetworkedButton(text, )


	function PANEL:AddReadyButtonFunction(text, weight, condition, func, admin)
		for k,v in pairs(self.ReadyButtonFuncs) do
			if weight > v.Weight then
				table.insert(self.ReadyButtonFuncs, k, {Weight = weight, Text = text, Condition = condition, Function = func, Admin = admin})
				if k <= self.CurrentReadyButtonFunc then self.CurrentReadyButtonFunc = self.CurrentReadyButtonFunc + 1 end -- We pushed the currently selected one down
				return
			end
		end
		table.insert(self.ReadyButtonFuncs, {Weight = weight, Text = text, Condition = condition, Function = func, Admin = admin})
	end

	local function thinkreadybutton(self)
		for k,v in pairs(self.Menu.ReadyButtonFuncs) do
			if v.Condition() then
				if k ~= self.Menu.CurrentReadyButtonFunc then
					self:SetText(v.Text)
					self.ClickFunction = v.Function
					self.Menu.CurrentReadyButtonFunc = k

					if v.Admin then
						self:SetDisabled(not nzu.IsAdmin(LocalPlayer()))
						self.AdminOnly = true
					else
						self:SetDisabled(false)
						self.AdminOnly = false
					end
				end
				return
			end
		end

		if self.Menu.CurrentReadyButtonFunc ~= 0 then
			self:SetText("[No valid action]")
			self:SetDisabled(true)
		end
	end
	function PANEL:SetConfig(config) self.ConfigPanel:SetConfig(config) end
	function PANEL:GetConfig() return self.ConfigPanel:GetConfig() end

	local countdowntextstates = {
		[ROUND_PREPARING] = "Prepare",
		[ROUND_ONGOING] = "Ongoing",
		[ROUND_GAMEOVER] = "GAME OVER"
	}
	local countdownsound = Sound("nzu/menu/countdown.wav")
	local function countdownthink(s)
		local state = nzu.Round:GetState()
		if s.State ~= state then
			if countdowntextstates[state] then
				s:SetText("GAME ACTIVE - ["..countdowntextstates[state].."]")
			end

			local old = s.State
			s.State = state
			s.LastCountdown = nil
			s:SetVisible(state ~= ROUND_WAITING)

			if old == ROUND_WAITING and LocalPlayer():IsReady() then
				s.Menu:Close() -- Close menu on game start
			end
		end

		if s.State == ROUND_WAITING then
			if nzu.Round.GameStart then
				if not s:IsVisible() then s:Show() end
				local diff = math.ceil(nzu.Round.GameStart - CurTime())
				if diff >= 0 then
					if diff ~= s.LastCountdown then
						s:SetText("GAME STARTING - [Spawn in "..(diff > 0 and diff or 0).."...]")
						s.LastCountdown = diff

						-- Play UI sound
						surface.PlaySound(countdownsound)
					end
					return
				end
			end
			if s:IsVisible() then
				s:Hide()
			end
		elseif s.State == ROUND_INVALID then
			if not s.NextRandomize or s.NextRandomize < CurTime() then
				local str = ""
				for i = 1,10 do
					str = str .. string.char(math.random(32,126))
				end
				s:SetText("GAME ACTIVE - ["..str.."]")
				s.NextRandomize = CurTime() + 0.025
			end
		end
	end

	--[[sound.Add({
		name = "nzu_menu_music",
		channel = CHAN_STATIC,
		pitch = 100,
		level = 0, -- global
		sound = "",
	})]]

	function PANEL:Init()
		self:ParentToHUD()
		self:Dock(FILL)

		self.LeftSide = self:Add("DDragBase") -- So buttons are clickable
		self.LeftSide:Dock(LEFT)
		self.LeftSide:SetWide(600)
		self.LeftSide:DockMargin(100,100,50,50)

		self.CloseButton = self:Add("DButton")
		self.CloseButton:SetPos(50,25)
		self.CloseButton:SetSize(120, 40)
		self.CloseButton:SetText("")

		self.CloseButton.F1 = self.CloseButton:Add("DLabel")
		self.CloseButton.F1:Dock(LEFT)
		self.CloseButton.F1:SetWide(self.CloseButton:GetTall())
		self.CloseButton.F1:SetText("F1")
		self.CloseButton.F1:SetFont("Trebuchet24")
		self.CloseButton.F1:SetContentAlignment(5)

		self.CloseButton.Text = self.CloseButton:Add("DLabel")
		self.CloseButton.Text:Dock(FILL)
		self.CloseButton.Text:SetText("Close")
		self.CloseButton.Text:SetFont("Trebuchet24")
		self.CloseButton.Text:SetContentAlignment(5)
		self.CloseButton.Text:DockMargin(0,3,3,3)

		self.CloseButton.F1.Paint = function(s,w,h)
			surface.SetDrawColor(255,255,255,10)
			surface.DrawRect(0,0,h,h)
		end

		self.CloseButton.Think = function(s)
			if not s.CanClose or s.CanClose ~= self:CanClose() then
				s:SetEnabled(self:CanClose())
				s.CanClose = s:IsEnabled()
			end
		end
		self.CloseButton.DoClick = function()
			self:Toggle()
		end

		self.ConsoleClose = self:Add("DLabel")
		self.ConsoleClose:SetPos(50,25 + self.CloseButton:GetTall())
		self.ConsoleClose:SetText("Console: nzu_menu")
		self.ConsoleClose:SetWide(self.CloseButton:GetWide())

		-- The loaded config icon
		self.ConfigPanel = self.LeftSide:Add("nzu_ConfigImagePanel")
		self.ConfigPanel:Dock(BOTTOM)
		self.ConfigPanel:SetMaintainAspectRatio(true)
		self.ConfigPanel:DockMargin(0,35,0,0)
		self.ConfigPanel:SetNoConfigAuthors("Use the Load Configs menu to select a Config to load.")

		self.RightSide = self:Add("DDragBase")
		self.RightSide:Dock(RIGHT)
		self.RightSide:SetWide(600)
		self.RightSide:DockMargin(50,100,100,50)

		self.PlayerIndicator = self.RightSide:Add("DPanel")
		self.PlayerIndicator:SetTall(40)
		self.PlayerIndicator:DockMargin(0,0,0,5)

		self.PlayerIndicator.Model = self.PlayerIndicator:Add("DLabel")
		self.PlayerIndicator.Model:SetText("Character")
		self.PlayerIndicator.Model:DockMargin(0,0,0,0)
		self.PlayerIndicator.Model:SetContentAlignment(5)
		self.PlayerIndicator.Model:Dock(LEFT)

		self.PlayerIndicator.Name = self.PlayerIndicator:Add("DLabel")
		self.PlayerIndicator.Name:SetText("Name")
		self.PlayerIndicator.Name:SetContentAlignment(5)
		self.PlayerIndicator.Name:Dock(FILL)

		self.PlayerIndicator.Ping = self.PlayerIndicator:Add("DLabel")
		self.PlayerIndicator.Ping:SetText("Ping")
		self.PlayerIndicator.Ping:SetContentAlignment(5)
		self.PlayerIndicator.Ping:Dock(RIGHT)

		self.PlayerIndicator.Mute = self.PlayerIndicator:Add("DLabel")
		self.PlayerIndicator.Mute:SetText("Mute")
		self.PlayerIndicator.Mute:SetContentAlignment(5)
		self.PlayerIndicator.Mute:Dock(RIGHT)

		self.PlayerIndicator:Dock(TOP)
		self.PlayerIndicator.Paint = function(s,w,h)
			surface.SetDrawColor(0,0,0,220)
			surface.DrawRect(0,0,w,h)

			drawcorneredbox(w,h,3,15)
		end

		self.PlayerList = self.RightSide:Add("DScrollPanel")
		self.PlayerList:Dock(FILL)
		

		-- Add a middle panel for parenting special displays right in the center of the menu (depending on space)
		self.MiddleCanvas = self:Add("DDragBase")
		self.MiddleCanvas:Dock(FILL)
		self.MiddleCanvas:DockMargin(0,100,0,100)		

		-- The menu list
		self.MenuRoot = self.LeftSide:Add("nzu_MenuPanel_SubMenu")
		self.MenuRoot:DockMargin(0,0,0,50)
		self.MenuRoot:Dock(FILL)
		self.MenuRoot.Menu = self

		self.ReadyButtonFuncs = {}
		self.CurrentReadyButtonFunc = -1 -- Cause refresh next think

		-- Now populate! Ready button needs its base conditions set
		self.ReadyButton = self:AddButton("", 1)
		self.ReadyButton.Menu = self
		self.ReadyButton.Think = thinkreadybutton

		self:AddReadyButtonFunction("Unspawn", 1000, function() return nzu.Round:GetState() ~= ROUND_GAMEOVER and not LocalPlayer():IsUnspawned() end, nzu.Unready)
		self:AddReadyButtonFunction("Unready", 100, function() return LocalPlayer():IsReady() end, nzu.Unready)
		self:AddReadyButtonFunction("Ready", 50, function() return nzu.CurrentConfig and nzu.Round:GetState() == ROUND_WAITING end, nzu.Ready)
		self:AddReadyButtonFunction("Spawn In", 40, function() return nzu.CurrentConfig and nzu.Round:GetState() ~= ROUND_GAMEOVER end, nzu.Ready)

		self.PlayerList.Think = function(s)
			local plys = player.GetAll()
			for id, pl in pairs(plys) do
				if not IsValid(pl.MenuEntry) then
					pl.MenuEntry = s:Add("nzu_MenuPanel_PlayerLine")
					pl.MenuEntry.Menu = self
					pl.MenuEntry:Setup(pl)
					pl.MenuEntry:Dock(TOP)
					s:AddItem(pl.MenuEntry)
				end
			end
		end

		self.Countdown = self.LeftSide:Add("DPanel")
		self.Countdown:Dock(BOTTOM)
		self.Countdown:DockPadding(10,5,10,5)
		self.Countdown:SetZPos(1)
		self.Countdown:DockMargin(0,35,0,-33)
		self.Countdown:SetTall(30)

		self.CountdownText = self.Countdown:Add("DLabel")
		self.CountdownText:SetText("")
		self.CountdownText:Dock(FILL)
		self.CountdownText:SetContentAlignment(4)
		self.CountdownText:SetFont("ChatFont")
		self.CountdownText:SetTextColor(color_black)

		self.CountdownText.Menu = self
		--self.CountdownText.Think = countdownthink
		local s = self.CountdownText
		self.Countdown.Think = function() countdownthink(s) end
		self.Countdown.Paint = function(cd,w,h)
			if s:IsVisible() then
				surface.SetDrawColor(200,200,200,255)
				surface.DrawRect(0,0,w,h)
			end
		end

		-- TODO: Add the link and uncomment this section when the server is open
		self.Promo = self.LeftSide:Add("DImageButton")
		self.Promo:Dock(BOTTOM)
		self.Promo:SetTall(75)
		self.Promo:SetImage("nzombies-unlimited/menu/discord-promo.png")
		self.Promo:SetZPos(-1)
		self.Promo:DockMargin(0,5,0,0)

		local link = "https://discord.gg/eJpVSqm"
		self.Promo.DoClick = function()
			local frame = vgui.Create("DFrame")
			frame:SetSkin("nZombies Unlimited")
			frame:SetBackgroundBlur(true)
			frame:SetTitle("Discord Link")
			frame:SetDeleteOnClose(true)
			frame:ShowCloseButton(true)
			frame:SetSize(300, 120)

			local lbl = frame:Add("DLabel")
			lbl:SetText("Click to copy to clipboard")
			lbl:Dock(TOP)
			lbl:SetContentAlignment(5)

			local txt = frame:Add("DButton")
			txt:SetText(link)
			txt:Dock(TOP)
			txt:SetContentAlignment(5)
			txt.DoClick = function(s)
				SetClipboardText(link)
				lbl:SetText("Copied!")
				lbl:SetTextColor(Color(0,255,0))
				s:KillFocus()
			end
			local sk = txt:GetSkin()
			txt.Paint = function(s,w,h) sk.tex.TextBox( 0, 0, w, h ) end

			local but = frame:Add("DButton")
			but:SetText("Open in Steam Overlay")
			but:Dock(BOTTOM)
			but:SetTall(25)
			but:DockMargin(30,0,30,0)
			but.DoClick = function()
				gui.OpenURL(link)
				frame:Close()
			end

			frame:MakePopup()
			frame:Center()
			frame:SetMouseInputEnabled(true)
			frame:DoModal()
		end

		-- Music!
		--[[local rsctr = self.RightSide:Add("DPanel")
		rsctr:Dock(BOTTOM)
		rsctr:SetTall(36)
		rsctr.m_bDrawCorners = true

		self.RightSideControls = rsctr:Add("DHorizontalScroller")
		self.RightSideControls:Dock(FILL)
		self.RightSideControls:DockPadding(10,10,10,10)

		local mus = self.RightSideControls:Add("DCheckBoxLabel")
		mus:SetText("Music")
		mus:Dock(RIGHT)
		mus:SetContentAlignment(5)
		mus:SetWide(50)
		mus.OnChange = function(s,b)
			local lp = LocalPlayer()
			if not b and lp.nzu_MenuMusicPlaying then
				lp:StopSound("nzu_menu_music")
				lp.nzu_MenuMusicPlaying = nil
			elseif b and not lp.nzu_MenuMusicPlaying then
				lp:EmitSound("nzu_menu_music")
				lp.nzu_MenuMusicPlaying = true
			end
		end
		mus:SetConVar("nzu_menu_music")
		self.RightSideControls.MusicToggle = mus]]

		self:SetConfig(nzu.CurrentConfig) -- Unloaded or whichever config is loaded when we first open the menu
		self.MenuRoot:Show()
	end
	--if not ConVarExists("nzu_menu_music") then CreateConVar("nzu_menu_music", 1, FCVAR_ARCHIVE, "Sets whether Music should play on the main menu of nZombies Unlimited.") end

	function PANEL:CanClose()
		return nzu.Round:GetState() ~= ROUND_WAITING or (IsValid(LocalPlayer()) and not LocalPlayer():IsUnspawned()) -- Can't close in waiting state, unless we're spawned
	end
	
	function PANEL:Paint()
		Derma_DrawBackgroundBlur(self, 0)
		surface.SetDrawColor(25,25,25,200)
		self:DrawFilledRect()
	end

	function PANEL:Open()
		self:Show()
		self:MakePopup()
		self:SetKeyBoardInputEnabled(false)
		self:RequestFocus()

		--if GetConVar("nzu_menu_music") then self.RightSideControls.MusicToggle:OnChange(true) end
	end

	function PANEL:Close()
		--[[local lp = LocalPlayer()
		if lp.nzu_MenuMusicPlaying then
			lp:StopSound("nzu_menu_music")
			lp.nzu_MenuMusicPlaying = nil
		end]]
		self:Hide()
	end

	function PANEL:ParentPanelToCenter(panel)
		panel:SetParent(self.MiddleCanvas)
	end

	function PANEL:Toggle()
		if self:IsVisible() then
			if self:CanClose() then self:Close() end
		else
			self:Open()
		end
	end
	vgui.Register("nzu_MenuPanel", PANEL, "Panel")

	local function createmenu()
		if IsValid(nzu.Menu) then nzu.Menu:Remove() end
		local mainmenu = vgui.Create("nzu_MenuPanel")
		mainmenu:SetSkin("nZombies Unlimited")
		nzu.Menu = mainmenu
		hook.Run("nzu_MenuCreated", mainmenu)

		return mainmenu
	end

	local function togglemenu()
		local mainmenu = nzu.Menu

		if net.ReadBool() then
			if net.ReadBool() then
				if not IsValid(mainmenu) then
					if IsValid(LocalPlayer()) then
						mainmenu = createmenu()
					else return end
				end
				mainmenu:Open()
			elseif mainmenu then
				mainmenu:Close()
			end
		else
			if not mainmenu then
				createmenu()
				mainmenu:Open()
			else
				mainmenu:Toggle()
			end
		end
		
	end
	net.Receive("nzu_OpenMenu", togglemenu)

	hook.Add("InitPostEntity", "nzu_Menu_InitializeMenu", function()
		if not IsValid(nzu.Menu) then
			createmenu()
			nzu.Menu:Open()
		end
	end)

	-- Console commands!
	concommand.Add("nzu_menu", function()
		if IsValid(nzu.Menu) then
			nzu.Menu:Toggle()
		elseif IsValid(LocalPlayer()) then
			createmenu()
			nzu.Menu:Open()
		end
	end, nil, "Toggles the Main Menu of nZombies Unlimited.")

	concommand.Add("nzu_menu_reload", function()
		if IsValid(nzu.Menu) then
			nzu.Menu:Remove()
		end
		if IsValid(LocalPlayer()) then
			createmenu()
			nzu.Menu:Open()
		end
	end, nil, "Removes and re-creates the Main Menu of nZombies Unlimited.")

else
	util.AddNetworkString("nzu_OpenMenu")
	hook.Add("ShowHelp", "nzu_OpenMenu", function(ply)
		net.Start("nzu_OpenMenu")
			net.WriteBool(false)
		net.Send(ply)
	end)

	hook.Add("nzu_PlayerUnspawned", "nzu_OpenMenu", function(ply)
		net.Start("nzu_OpenMenu")
			net.WriteBool(true)
			net.WriteBool(true)
		net.Send(ply)
	end)

	util.AddNetworkString("nzu_CustomizePlayerDone")
	net.Receive("nzu_CustomizePlayerDone", function(len, ply)
		ply:UpdateModel()
	end)
end