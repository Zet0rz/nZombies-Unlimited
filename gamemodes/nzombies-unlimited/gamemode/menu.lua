
if CLIENT then
	local PANEL = {}

	-- Important functions for you developers out there here at the top
	function PANEL:AddMenuButton(text, zpos, func, submenu)

	end

	function PANEL:AddMenuSubMenu(text, zpos, submenu)

	end
	
	function PANEL:AddMenuPanel(text, zpos, panel, submenu)

	end

	function PANEL:AddMenuSheet(text, zpos, panel)
		local but = vgui.Create("DButton")
		function but.Paint(s)
			surface.SetDrawColor(0,0,0,230)
			s:DrawFilledRect()
		end
		self.MenuRoot:Add(s)
		but:SetZPos(zpos)
		but:SetText(text)
		but.DoClick = function(s)
			self:ShowMenuSheet(text)
		end

		self.MenuItems[text] = panel
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

		self.LeftSide = self:Add("Panel")
		self.LeftSide:Dock(LEFT)
		self.LeftSide:SetWide(600)
		self.LeftSide:DockMargin(100,100,50,100)

		-- The loaded config icon
		self.ConfigPanel = self.LeftSide:Add("DImage")
		self.ConfigPanel:Dock(BOTTOM)
		self.ConfigPanel:SetTall(337)

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
		self.MenuItems = {}
		self.MenuRoot = self.LeftSide:Add("DScrollSheet")
		self.MenuRoot:DockMargin(0,0,0,50)
		self.MenuRoot:Dock(FILL)

		
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
	end

	function PANEL:Close()
		self:Hide()
	end

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