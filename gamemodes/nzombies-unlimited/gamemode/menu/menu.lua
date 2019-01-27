
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
	local function generatebutton(text,admin)
		local b = vgui.Create("DButton")
		b:SetFont("DermaLarge")
		b:SetText(" " .. text .. " ") -- Append spaces around to free from edges
		b:SetTextColor(textcolor)
		b:SetContentAlignment(4)
		b:DockMargin(1,1,1,1)
		b:SetTall(50)

		b.AdminOnly = admin

		b.Paint = paintfunc
		b.DoClick = buttondoclick

		return b
	end
	function SUBMENU:AddButton(text, zpos, func, admin)
		if IsValid(self.List) then
			local b = generatebutton(text, admin)
			b:SetZPos(zpos)
			b.SubMenu = self
			b.ClickFunction = func
			self.List:Add(b)
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
		if IsValid(self.List) then
			local b = generatebutton(text, admin)
			b:SetZPos(zpos)

			local submenu = vgui.Create("nzu_MenuPanel_SubMenu")
			submenu:SetParent(self:GetParent())
			submenu:Dock(FILL)
			submenu.Menu = self.Menu

			b.SubMenu = self
			b.SubPanel = submenu
			submenu:SetPrevious(text, self)
			b.ClickFunction = submenuclick
			self.List:Add(b)

			return submenu
		end
	end
	function SUBMENU:AddPanel(text, zpos, panel, admin)
		if IsValid(self.List) then
			local b = generatebutton(text, admin)
			b:SetZPos(zpos)

			local submenu = vgui.Create("nzu_MenuPanel_SubMenu")
			submenu:SetParent(self:GetParent())
			submenu:Dock(FILL)
			submenu:SetContents(panel)
			submenu.Menu = self.Menu

			b.SubMenu = self
			b.SubPanel = submenu
			submenu:SetPrevious(text, self)
			b.ClickFunction = submenuclick
			self.List:Add(b)

			return submenu
		end
	end

	--local i = 1
	function SUBMENU:Init()
		local topbar = self:Add("Panel")
		topbar:Dock(TOP)
		topbar:SetTall(40)

		self.BackButton = generatebutton(" < Back")
		self.BackButton:SetParent(topbar)
		self.BackButton:SizeToContents()
		self.BackButton:Dock(LEFT)
		self.BackButton:SetContentAlignment(4)
		self.BackButton.DoClick = submenuclick
		self.BackButton.SubMenu = self
		self.BackButton:Hide()

		self.Contents = self:Add("DScrollPanel")
		self.Contents:SetPaintBackground(false)
		self.Contents:Dock(FILL)

		self.List = self.Contents:Add("DListLayout")
		self.List:Dock(FILL)

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
	function SUBMENU:OnShown() end
	function SUBMENU:OnHid() end
	vgui.Register("nzu_MenuPanel_SubMenu", SUBMENU, "Panel")

	local PLAYER_AVATAR = {}
	function PLAYER_AVATAR:Init()
		self.Icon = vgui.Create("ModelImage", self)
		self.Icon:Dock(FILL)
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
		end
	end
	local glowmat = Material("particle/particle_glow_04")
	function PLAYER_AVATAR:Paint(w,h)
		surface.SetDrawColor(0,0,0,200)
		self:DrawFilledRect()

		if IsValid(self.Player) then
			local col = self.Player:GetPlayerColor()

			surface.SetDrawColor(col.x * 150 + 100, col.y * 150 + 100, col.z * 150 + 100, 200)
			surface.SetMaterial(glowmat)
			surface.DrawTexturedRect(-10,-10,w+20,h+20)
		end
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
		self.Character:SetWide(54)
		self.Character:DockMargin(5,5,15,5)
		self.Character:Dock(LEFT)

		local pnl = self:Add("DPanel")
		pnl:DockPadding(10,10,10,10)
		pnl:Dock(FILL)
		pnl.Paint = barpaint

		self.Avatar = pnl:Add("AvatarImage")
		self.Avatar:SetWide(44)
		self.Avatar:Dock(LEFT)

		self.Ping = pnl:Add("DLabel")
		self.Ping:Dock(RIGHT)
		self.Ping:SetFont("HudHintTextLarge")
		self.Ping:SetContentAlignment(5)
		--self.Ping:SetZPos(0)

		self.Mute = pnl:Add("DImageButton")
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

		self.Name = pnl:Add("DLabel")
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

	-- Internal functions you don't really need to worry about
	function PANEL:SetConfig(config)
		local img = config and config.Icon or "maps/thumb/gm_construct.png"
		local name = config and config.Name or "Some really long config name right here"
		local authors = config and config.Authors or "Zet0r, other authors..."
		local map = config and config.Map or "gm_construct"

		self.ConfigPanel:SetImage(img)
		self.ConfigPanel.Map:SetText(map)
		self.ConfigPanel.Map:SizeToContents()
		self.ConfigPanel.Name:SetText(name)
		self.ConfigPanel.Name:SizeToContents()
		self.ConfigPanel.Authors:SetText(authors)
		self.ConfigPanel.Authors:SizeToContents()
	end

	function PANEL:Init()

		self:ParentToHUD()
		self:Dock(FILL)
		self.OpenTime = 0

		self.LeftSide = self:Add("DDragBase") -- So buttons are clickable
		self.LeftSide:Dock(LEFT)
		self.LeftSide:SetWide(600)
		self.LeftSide:DockMargin(100,100,50,100)

		-- The loaded config icon
		self.ConfigPanel = self.LeftSide:Add("DImage")
		self.ConfigPanel:Dock(BOTTOM)
		self.ConfigPanel:SetTall(337)
		self.ConfigPanel:DockMargin(0,35,0,0)

		self.ConfigPanel.InfoBar = self.ConfigPanel:Add("Panel")
		self.ConfigPanel.InfoBar:Dock(BOTTOM)
		self.ConfigPanel.InfoBar:SetTall(45)
		function self.ConfigPanel.InfoBar.Paint(s)
			surface.SetDrawColor(0,0,0,220)
			s:DrawFilledRect()
		end

		local namemap = self.ConfigPanel.InfoBar:Add("Panel")
		namemap:Dock(TOP)
		namemap:SetTall(40)

		self.ConfigPanel.Name = namemap:Add("DLabel")
		self.ConfigPanel.Name:SetFont("Trebuchet24")
		self.ConfigPanel.Name:SetTextColor(color_white)
		self.ConfigPanel.Name:Dock(LEFT)
		self.ConfigPanel.Name:DockMargin(5,0,5,10)

		self.ConfigPanel.Map = namemap:Add("DLabel")
		--self.ConfigPanel.Map:SetFont("Trebuchet24")
		self.ConfigPanel.Map:SetTextColor(Color(200,200,200))
		self.ConfigPanel.Map:Dock(LEFT)
		self.ConfigPanel.Map:DockMargin(5,0,5,5)

		self.ConfigPanel.Authors = self.ConfigPanel.InfoBar:Add("DLabel")
		--self.ConfigPanel.Authors:SetFont("Trebuchet24")
		self.ConfigPanel.Authors:SetTextColor(Color(150,150,150))
		self.ConfigPanel.Authors:Dock(BOTTOM)
		self.ConfigPanel.Authors:DockMargin(5,5,5,5)

		self.RightSide = self:Add("DDragBase")
		self.RightSide:Dock(RIGHT)
		self.RightSide:SetWide(600)
		self.RightSide:DockMargin(50,100,100,100)

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
		self.PlayerList.Think = function(s)
			local plys = player.GetAll()
			for id, pl in pairs(plys) do
				if not IsValid(pl.MenuEntry) then
					pl.MenuEntry = s:Add("nzu_MenuPanel_PlayerLine")
					pl.MenuEntry:Setup(pl)
					pl.MenuEntry:Dock(TOP)
					s:AddItem(pl.MenuEntry)
				end
			end
		end

		-- Add a middle panel for parenting special displays right in the center of the menu (depending on space)
		self.MiddleCanvas = self:Add("DDragBase")
		self.MiddleCanvas:Dock(FILL)
		self.MiddleCanvas:DockMargin(0,100,0,100)

		self:SetConfig() -- unloaded

		-- The menu list
		self.MenuRoot = self.LeftSide:Add("nzu_MenuPanel_SubMenu")
		self.MenuRoot:DockMargin(0,0,0,50)
		self.MenuRoot:Dock(FILL)
		self.MenuRoot.Menu = self

		-- Now populate!
		self:AddButton("Ready up", 1, function() print("Readying") end)

		local configs = self:AddSubMenu("Load config ...", 3, true)
		configs:AddButton("gm_construct - or something")
		configs:AddButton("Breakout")
		configs:AddButton("Imprisoned")
		for i = 1,15 do
			configs:AddButton("Demonstrating scroll: ".. i)
		end
			
		local ext = vgui.Create("DPanel")
		self:AddPanel("Extension Settings...", 4, ext, true)

		self.MenuRoot:Show()
		
	end
	
	function PANEL:Paint()
		Derma_DrawBackgroundBlur(self, self.OpenTime)
		surface.SetDrawColor(25,25,25,200)
		self:DrawFilledRect()
	end

	function PANEL:Open()
		self:Show()
		self:MakePopup()
		self:SetKeyBoardInputEnabled(false)
		self:RequestFocus()
	end

	function PANEL:Close()
		self:Hide()
	end

	function PANEL:ParentPanelToCenter(panel)
		panel:SetParent(self.MiddleCanvas)
	end

	--function PANEL:DoClick() print("hfiua") end

	function PANEL:Toggle()
		if self:IsVisible() then self:Close() else self:Open() end
	end
	vgui.Register("nzu_MenuPanel", PANEL, "Panel")

	local menuhooks = {}
	local function togglemenu()
		local mainmenu = nzu.Menu
		if mainmenu then mainmenu:Remove() mainmenu = nil end
		if not mainmenu then
			mainmenu = vgui.Create("nzu_MenuPanel")
			nzu.Menu = mainmenu
			for k,v in pairs(menuhooks) do
				v(mainmenu)
			end
			mainmenu:Open()
		else
			mainmenu:Toggle()
		end
	end
	net.Receive("nzu_OpenMenu", togglemenu)

	function nzu.AddMenuHook(id, func)
		menuhooks[id] = func
		if IsValid(nzu.Menu) then
			func(nzu.Menu)
		end
	end
	function nzu.RemoveMenuHook(id)
		menuhooks[id] = nil
	end

else
	util.AddNetworkString("nzu_OpenMenu")
	hook.Add("ShowHelp", "nzu_OpenMenu", function(ply)
		net.Start("nzu_OpenMenu")
		net.Send(ply)
	end)

	util.AddNetworkString("nzu_CustomizePlayerDone")
	net.Receive("nzu_CustomizePlayerDone", function(len, ply)
		local c_mdl = ply:GetInfo("cl_playermodel")
		local mdl = player_manager.TranslatePlayerModel(c_mdl)
		util.PrecacheModel(mdl)
		ply:SetModel(mdl)
		ply:SetPlayerColor(Vector(ply:GetInfo("cl_playercolor")))

		local col = Vector(ply:GetInfo("cl_weaponcolor"))
		if col:Length() == 0 then
			col = Vector(0.001, 0.001, 0.001)
		end
		ply:SetWeaponColor(col)
	end)
end