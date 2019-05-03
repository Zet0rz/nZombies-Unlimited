
--[[-------------------------------------------------------------------------
Config List panel [nzu_ConfigList]
Child of ScrollPanel which can automatically list a set of [nzu_ConfigPanel]s
---------------------------------------------------------------------------]]

local PANEL = {}
AccessorFunc(PANEL, "m_bAllowSelect", "Selectable", FORCE_BOOL)

function PANEL:Init()
	self.MapConfigList = self:Add("DListLayout")
	self.MapConfigList:Dock(TOP)
	self.MapConfigList:DockMargin(0,0,0,25)
	self.OtherConfigList = self:Add("DListLayout")
	self.OtherConfigList:Dock(TOP)
	
	self.ConfigPanels = {}
	
	self.NoCurrentMapConfigs = self.MapConfigList:Add("DLabel")
	self.NoCurrentMapConfigs:SetText("No Configs for the current map")
	self.NoCurrentMapConfigs:SetContentAlignment(5)
	self.NoCurrentMapConfigs:SetFont("Trebuchet18")
	
	self.MapConfigList.OnChildRemoved = function(s)
		if s:ChildCount() == 1 then self.NoCurrentMapConfigs:SetVisible(true) end
	end
end

function PANEL:LoadConfigs()
	local tbl = nzu.GetConfigs()
	if tbl then
		for k,v in pairs(tbl) do
			for k2,v2 in pairs(v) do
				self:AddConfig(v2)
			end
		end
	end
	
	hook.Add("nzu_ConfigInfoSaved", self, self.AddConfig)
	hook.Add("nzu_ConfigDeleted", self, self.RemoveConfig)
end

function PANEL:Clear()
	for k,v in pairs(self.ConfigPanels) do
		if IsValid(v) then v:Remove() end
	end
	self.ConfigPanels = {}
	
	hook.Remove("nzu_ConfigInfoSaved", self)
	hook.Remove("nzu_ConfigDeleted", self)
end

function PANEL:SetConfigPanelHeight(height)
	self.m_iPanelHeight = height
	self.MapConfigList:DockMargin(0,0,0,math.Round(height/2))
end

function PANEL:SelectConfig(cfg)
	if cfg and self.ConfigPanels[cfg] then
		if self.ConfigPanels[cfg] == self.SelectedPanel then return end

		if IsValid(self.SelectedPanel) then self.SelectedPanel:SetSelected(false) end

		self.SelectedConfig = cfg
		self.SelectedPanel = self.ConfigPanels[cfg]
		self.ConfigPanels[cfg]:SetSelected(true)
	else
		if IsValid(self.SelectedPanel) then self.SelectedPanel:SetSelected(false) end
		self.SelectedConfig = nil
		self.SelectedPanel = nil
	end

	self:OnConfigSelected(self.SelectedConfig, self.SelectedPanel)
end

function PANEL:AddConfig(cfg)
	if self.ConfigPanels[cfg] then return self.ConfigPanels[cfg] end

	local pnl = cfg
	if not IsValid(pnl) then
		pnl = vgui.Create("nzu_ConfigPanel", self)
		pnl:SetConfig(cfg)
		pnl:SetTall(self.m_iPanelHeight or 50)
	end
	
	pnl.DoClick = function(s)
		if self:GetSelectable() then self:SelectConfig(s.Config) end
		self:OnConfigClicked(s.Config, s)
	end
	pnl:Dock(TOP)
	
	if pnl.Config and pnl.Config.Map == game.GetMap() then
		self.MapConfigList:Add(pnl)
		self.NoCurrentMapConfigs:SetVisible(false)
	else
		self.OtherConfigList:Add(pnl)
	end
	
	self.ConfigPanels[pnl.Config] = pnl
	self:SortConfigs()
	
	return pnl
end

function PANEL:RemoveConfig(cfg)
	if self.ConfigPanels[cfg] then
		self.ConfigPanels[cfg]:Remove()
	end
	self.ConfigPanels[cfg] = nil
end

function PANEL:GetConfigs()
	return table.GetKeys(self.ConfigPanels)
end

function PANEL:GetConfigPanel(cfg)
	return self.ConfigPanels[cfg]
end

local sortorder = {
	Official = 3,
	Local = 2,
	Workshop = 1
}
local function sorter(a,b)
	local order1 = sortorder[a.Type] or 0
	local order2 = sortorder[b.Type] or 0
	
	return order1 == order2 and a.Name < b.Name or order1 < order2
end
function PANEL:SortConfigs()
	local t = {}
	for k,v in pairs(self.ConfigPanels) do
		table.insert(t, k)
	end
	table.sort(t, sorter)
	
	for k,v in ipairs(t) do
		self:GetConfigPanel(v):SetZPos(k)
	end
end

function PANEL:OnConfigClicked(cfg, pnl)
	-- Override me :D
end

function PANEL:OnConfigSelected(cfg, pnl)
	-- Override me too :D
end

function PANEL:GetSelectedConfig()
	return self.SelectedConfig, self.SelectedPanel
end

vgui.Register("nzu_ConfigList", PANEL, "DScrollPanel")



--[[-------------------------------------------------------------------------
Config Panel [nzu_ConfigPanel]
A panel that shows a small clickable bar of a Config
---------------------------------------------------------------------------]]
local CONFIGPANEL = {}
local emptyfunc = function() end
function CONFIGPANEL:Init()
	self.Thumbnail = self:Add("DImage")
	self.Thumbnail:Dock(LEFT)

	local status = self:Add("Panel")
	status:Dock(RIGHT)

	self.Type = status:Add("DLabel")
	self.Type:Dock(TOP)
	self.Type:SetContentAlignment(3)
	self.Type:SetText("")

	self.MapStatus = status:Add("DLabel")
	self.MapStatus:Dock(BOTTOM)
	self.MapStatus:SetContentAlignment(9)
	self.MapStatus:SetText("")

	local center = self:Add("Panel")
	center:Dock(FILL)
	center:DockMargin(5,0,5,0)

	self.Name = center:Add("DLabel")
	self.Name:SetFont("Trebuchet24")
	self.Name:Dock(FILL)
	self.Name:SetContentAlignment(1)
	self.Name:SetText("No Config loaded")

	self.Map = center:Add("DLabel")
	self.Map:Dock(BOTTOM)
	self.Map:SetContentAlignment(7)
	self.Map:DockMargin(0,0,0,-5)
	self.Map:SetText("")

	self.Button = self:Add("DButton")
	self.Button:SetText("")
	self.Button:SetSize(self:GetSize())
	self.Button.Paint = emptyfunc
	self.Button.DoClick = function() self:DoClick() end

	self:DockPadding(5,5,5,5)
	self.Button:DockMargin(-5,-5,-5,-5)
	self.m_bDrawCorners = true
end

local typecolors = {
	Official = Color(255,0,0),
	Local = Color(0,0,255),
	Workshop = Color(150,0,255),
	Unsaved = Color(255,200,100),
}
local mapinstalled,mapnotinstalled = Color(100,255,100), Color(255,100,100)
local fallback = "vgui/black.png"
function CONFIGPANEL:Update(config)
	--print(self, config.Name, self.Config.Name)
	if self.Config == config then
		self.Name:SetText(config.Name or "")
		self.Map:SetText(config.Codename .. " || " .. config.Map)

		local status = file.Find("maps/"..config.Map..".bsp", "GAME")[1] and true or false
		self.MapStatus:SetText(status and "Map installed" or "Map not installed")
		self.MapStatus:SetTextColor(status and mapinstalled or mapnotinstalled)

		self.Type:SetText(config.Type)
		self.Type:SetTextColor(typecolors[config.Type] or color_white)
		
		self.Thumbnail:SetImage(nzu.GetConfigThumbnail(config) or fallback)
	end
end

function CONFIGPANEL:SetConfig(config)
	self.Config = config
	self:Update(config)
	timer.Simple(0, function() hook.Add("nzu_ConfigInfoSaved", self, self.Update) end) -- Auto-update ourselves whenever updates arrive to this config
end
function CONFIGPANEL:GetConfig() return self.Config end

function CONFIGPANEL:DoClick() end
function CONFIGPANEL:DoRightClick() end

function CONFIGPANEL:PerformLayout(w,h)
	self.Button:SetSize(w,h)
	self.Thumbnail:SetWide((h-10)*(16/9))
end

function CONFIGPANEL:Sort()
	if self.Config then
		self:SetZPos((self.Config.Map == game.GetMap() and 5 or 0) + (sortorder[self.Config.Type] or 0))
	else
		self:SetZPos(-1)
	end
end

local selectcol = Color(0,150,255)
function CONFIGPANEL:SetSelected(b)
	self:SetBackgroundColor(b and selectcol or nil)
	self.Selected = b
end
function CONFIGPANEL:GetSelected() return self.Selected end
vgui.Register("nzu_ConfigPanel", CONFIGPANEL, "DPanel")


--[[-------------------------------------------------------------------------
Config Image [nzu_ConfigImagePanel]
A large showcase of a Config. Shows a big thumbnail with overlayed info
This is what is used on the Main Menu
---------------------------------------------------------------------------]]

local MAPPANEL = {}
AccessorFunc(MAPPANEL, "m_bAspectRatio", "MaintainAspectRatio", FORCE_BOOL)

function MAPPANEL:Init()
	self.InfoBar = self:Add("Panel")
	self.InfoBar:Dock(BOTTOM)
	self.InfoBar:SetTall(45)
	function self.InfoBar.Paint(s)
		surface.SetDrawColor(0,0,0,252)
		s:DrawFilledRect()
	end

	local namemap = self.InfoBar:Add("Panel")
	namemap:Dock(TOP)
	namemap:SetTall(40)

	self.Name = namemap:Add("DLabel")
	self.Name:SetFont("Trebuchet24")
	self.Name:SetTextColor(color_white)
	self.Name:Dock(LEFT)
	self.Name:DockMargin(5,0,5,10)

	self.Map = namemap:Add("DLabel")
	--self.Map:SetFont("Trebuchet24")
	self.Map:SetTextColor(Color(200,200,200))
	self.Map:Dock(LEFT)
	self.Map:DockMargin(5,0,5,5)

	self.Authors = self.InfoBar:Add("DLabel")
	--self.Authors:SetFont("Trebuchet24")
	self.Authors:SetTextColor(Color(150,150,150))
	self.Authors:Dock(BOTTOM)
	self.Authors:DockMargin(5,5,5,5)
end

AccessorFunc(MAPPANEL, "m_strNoConfigImage", "NoConfigImage", FORCE_STRING)
AccessorFunc(MAPPANEL, "m_strNoConfigName", "NoConfigName", FORCE_STRING)
AccessorFunc(MAPPANEL, "m_strNoConfigMap", "NoConfigMap", FORCE_STRING)
AccessorFunc(MAPPANEL, "m_strNoConfigAuthors", "NoConfigAuthors", FORCE_STRING)
function MAPPANEL:SetConfig(config)
	self.Config = config
	if config then
		self:SetImage(nzu.GetConfigThumbnail(config))
		self.Map:SetText(config.Map)
		self.Map:SizeToContents()
		self.Name:SetText(config.Name)
		self.Name:SizeToContents()
		self.Authors:SetText(config.Authors)
		self.Authors:SizeToContents()			
	else
		self:SetImage(self:GetNoConfigImage() or "vgui/black")
		self.Map:SetText(self:GetNoConfigMap() or "")
		self.Map:SizeToContents()
		self.Name:SetText(self:GetNoConfigName() or "No Config selected")
		self.Name:SizeToContents()
		self.Authors:SetText(self:GetNoConfigAuthors() or "")
		self.Authors:SizeToContents()
	end
end

function MAPPANEL:PerformLayout(w,h)
	if self:GetMaintainAspectRatio() then
		local d = self:GetDock()
		if d == TOP or d == BOTTOM then
			self:SetTall(w * 9/16)
		elseif d == LEFT or d == RIGHT then
			self:SetWide(h * 16/9)
		end
	end
end

function MAPPANEL:GetConfig()
	return self.Config
end

vgui.Register("nzu_ConfigImagePanel", MAPPANEL, "DImage")