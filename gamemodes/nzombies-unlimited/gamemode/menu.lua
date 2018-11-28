
if CLIENT then
	local SUBMENU = {}
	local cornerthickness = 3
	local cornerlength = 15
	local textcolor = Color(220,220,220)
	local paintfunc = function(b, w, h) -- Draw the black button with the white corners
		if b.Hovered then
			surface.SetDrawColor(50,50,50,240)
		else
			surface.SetDrawColor(0,0,0,220)
		end
		b:DrawFilledRect()

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
	local function generatebutton(text)
		local b = vgui.Create("DButton")
		b:SetFont("DermaLarge")
		b:SetText(" " .. text .. " ") -- Append spaces around to free from edges
		b:SetTextColor(textcolor)
		b:SetContentAlignment(4)
		b:DockMargin(1,1,1,1)
		b:SetTall(50)

		b.Paint = paintfunc

		return b
	end
	function SUBMENU:AddButton(text, zpos, func)
		if IsValid(self.List) then
			local b = generatebutton(text)
			b:SetZPos(zpos)
			b.SubMenu = self
			b.DoClick = func
			self.List:Add(b)
		end
	end

	local function submenuclick(b)
		local s = b.SubMenu
		if IsValid(s) then
			local p = b.SubPanel
			if IsValid(p) then
				s:Hide()
				p:Show()
			end
		end
	end
	function SUBMENU:AddSubMenu(text, zpos)
		if IsValid(self.List) then
			local b = generatebutton(text)
			b:SetZPos(zpos)

			local submenu = vgui.Create("nzu_MenuPanel_SubMenu")
			submenu:SetParent(self:GetParent())
			submenu:Dock(FILL)
			submenu.Menu = self.Menu

			b.SubMenu = self
			b.SubPanel = submenu
			submenu:SetPrevious(text, self)
			b.DoClick = submenuclick
			self.List:Add(b)

			return submenu
		end
	end
	function SUBMENU:AddPanel(text, zpos, panel)
		if IsValid(self.List) then
			local b = generatebutton(text)
			b:SetZPos(zpos)

			local submenu = vgui.Create("nzu_MenuPanel_SubMenu")
			submenu:SetParent(self:GetParent())
			submenu:Dock(FILL)
			submenu:SetContents(panel)
			submenu.Menu = self.Menu

			b.SubMenu = self
			b.SubPanel = submenu
			submenu:SetPrevious(text, self)
			b.DoClick = submenuclick
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

		--self:AddButton("Ready up" .. i, 1, function() print("Ready!") end)
		--i = i + 1
		--timer.Simple(1, function() self:AddButton("Hi2", 1, function() print("nah") end) print("Added 2") end)

		self:Hide()
	end
	function SUBMENU:SetPrevious(text, panel)
		if IsValid(panel) then
			self.BackButton:Show()
			self.BackButton:SetText("  < ".. text .. " ")
			self.BackButton:SizeToContents()
			self.BackButton.SubPanel = panel
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
	vgui.Register("nzu_MenuPanel_SubMenu", SUBMENU, "Panel")

	local PANEL = {}

	-- Important functions for you developers out there here at the top
	function PANEL:AddButton(text, zpos, func)
		self.MenuRoot:AddButton(text, zpos, func)
	end

	function PANEL:AddSubMenu(text, zpos)
		return self.MenuRoot:AddSubMenu(text, zpos)
	end
	
	function PANEL:AddPanel(text, zpos, panel)
		self.MenuRoot:AddPanel(text, zpos, panel)
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

		self.PlayerList = self:Add("DScrollSheet")
		self.PlayerList:Dock(RIGHT)
		self.PlayerList:SetWide(600)
		self.PlayerList:DockMargin(50,100,100,100)

		self:SetConfig() -- unloaded

		-- The menu list
		self.MenuRoot = self.LeftSide:Add("nzu_MenuPanel_SubMenu")
		self.MenuRoot:DockMargin(0,0,0,50)
		self.MenuRoot:Dock(FILL)
		self.MenuRoot.Menu = self

		-- Now populate!
		self:AddButton("Ready up", 1, function() print("Readying") end)
		local configs = self:AddSubMenu("Load config ...", 2)
			configs:AddButton("gm_construct - or something")
			configs:AddButton("Breakout")
			configs:AddButton("Imprisoned")
			for i = 1,15 do
				configs:AddButton("Demonstrating scroll: ".. i)
			end
			
		local ext = vgui.Create("DPanel")
		self:AddPanel("Extension Settings...", 3, ext)

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

	--function PANEL:DoClick() print("hfiua") end

	function PANEL:Toggle()
		if self:IsVisible() then self:Close() else self:Open() end
	end
	vgui.Register("nzu_MenuPanel", PANEL, "Panel")

	local function togglemenu()
		local mainmenu = nzu.Menu
		if mainmenu then mainmenu:Remove() mainmenu = nil end
		if not mainmenu then
			mainmenu = vgui.Create("nzu_MenuPanel")
			nzu.Menu = mainmenu
			mainmenu:Open()
		else
			mainmenu:Toggle()
		end
	end
	net.Receive("nzu_OpenMenu", togglemenu)

else
	util.AddNetworkString("nzu_OpenMenu")
	hook.Add("ShowHelp", "nzu_OpenMenu", function(ply)
		net.Start("nzu_OpenMenu")
		net.Send(ply)
	end)
end