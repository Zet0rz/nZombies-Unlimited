print("Yo")

local INPUTPORT = {}
function INPUTPORT:Init()
	self:SetBackgroundColor(Color(150,255,150))
	self:SetSize(10,10)

	self:Receiver("nzu_logicmap_connection", self.DropAction)
end

function INPUTPORT:DropAction(pnls, dropped, menu, x, y)
	if dropped then
		print("Connected")
	end
end

local OUTPUTPORT = {}
function OUTPUTPORT:Init()
	self:SetBackgroundColor(Color(255,150,150))
	self:SetSize(10,10)

	self:Droppable("nzu_logicmap_connection")
end
derma.DefineControl("DLogicMapUnitInput", "", INPUTPORT, "DPanel")
derma.DefineControl("DLogicMapUnitOutput", "", OUTPUTPORT, "DPanel")

local PANEL = {}
AccessorFunc(PANEL,"m_bDisplayPorts", "ShowPorts", FORCE_BOOL)

function PANEL:SetLogicUnit(unit)
	if unit.CustomPanel then
		self:Clear()
		unit:CustomPanel(self)
	else
		if not self.Icon then self.Icon = self:Add("DImage") end
		self.Icon:SetImage(unit.Icon)
		--self.Icon:Dock(FILL)
		self.Icon:DockMargin(10,10,10,10)
		self.Icon:SetKeepAspect(true)
	end
	self.m_lUnit = unit
	self:UpdatePorts()
end

function PANEL:PerformLayout()
	if IsValid(self.Icon) then
		local x,y = self:GetSize()
		local min = math.Min(x,y) - 10
		self.Icon:SetSize(min,min)
		self.Icon:SetPos(x/2 - min/2, y/2 - min/2)
	end
end

function PANEL:UpdatePorts()
	if self.InputPorts then for k,v in pairs(self.InputPorts) do v:Remove() end end
	if self.OutputPorts then for k,v in pairs(self.OutputPorts) do v:Remove() end end
	if self:GetShowPorts() then
		self.InputPorts = {}
		self.OutputPorts = {}

		if IsValid(self.m_lUnit) then
			for k,v in pairs(self.m_lUnit.Outputs) do
				local p = self:Add("DLogicMapUnitOutput")
				p:SetPos(40, k*15)
			end

			local i = 1
			for k,v in pairs(self.m_lUnit.Inputs) do
				local p = self:Add("DLogicMapUnitInput")
				p:SetPos(0, i*15)
				i = i + 1
			end
		end
	else
		self.InputPorts = nil
		self.OutputPorts = nil
	end
end

--[[function PANEL:OnDrop()
	-- Override me!
	print("dhawjhdk")
end]]

function PANEL:OnDropIntoMap(x,y)
	-- Override me!
end
derma.DefineControl("DLogicMapUnit", "", PANEL, "DPanel")

local playermat = Material("icon16/arrow_right.png") -- Change this

local logicmapchips = {}
local logicmap
local function addunittomap(unit)
	if IsValid(logicmapchips[unit:Index()]) then return end

	if IsValid(logicmap) then
		local chip = vgui.Create("DLogicMapUnit", logicmap)
		chip:SetShowPorts(true)
		chip:SetLogicUnit(unit)
		chip:SetSize(50,50)
		local pos = unit:GetPos()
		logicmap:SetChildPos(chip, pos.x,pos.y)

		chip:Droppable("nzu_logicmap")
		chip.OnDropIntoMap = function(x,y)
			net.Start("nzu_logicmap_move")
				net.WriteUInt(unit:Index(), 16)
				net.WriteVector(Vector(x,y,0))
			net.SendToServer()
		end

		logicmapchips[unit:Index()] = chip
	end
end

nzu.AddSpawnmenuTab("Logic Map", "DPanel", function(panel)
	panel:SetSkin("nZombies Unlimited")
	panel:SetBackgroundColor(Color(100,100,100))

	local toolbarwidth = 150
	
	local sidebar = panel:Add("DCategoryList")
	sidebar:SetWide(toolbarwidth)
	sidebar:Dock(RIGHT)
	function sidebar:ReloadLogicUnits()
		sidebar:Clear()
		local cats = {}
		for k,v in pairs(nzu.GetLogicUnitList()) do
			if v.Spawnable then
				local cat = v.Category or "Uncategorized"
				if not cats[cat] then cats[cat] = {} end
				cats[cat][k] = v
			end
		end

		for k,v in pairs(cats) do
			local c = sidebar:Add(k)
			for k2,v2 in pairs(v) do
				local pnl = vgui.Create("DPanel", c)
				pnl:SetSize(140,75)
				pnl:DockMargin(5,5,5,5)
				pnl:Dock(TOP)

				local name = pnl:Add("DLabel")
				name:SetText(v2.Name)
				name:Dock(BOTTOM)
				name:SetTextColor(color_black)
				name:SetContentAlignment(5)

				local icon = pnl:Add("DLogicMapUnit")
				icon:SetLogicUnit(v2)
				icon:SetSize(50,50)
				icon:SetPos(42.5,5)
				icon:Droppable("nzu_logicmap")
				icon.OnDropIntoMap = function(s,x,y)
					net.Start("nzu_logicmap_create")
						net.WriteString(k2)
						net.WriteVector(Vector(x,y,0))
					net.SendToServer()
					return true -- Don't drop into map
				end

				c:UpdateAltLines()
			end
		end
	end
	sidebar:ReloadLogicUnits()

	local map = panel:Add("DScrollSheet")
	map:Dock(FILL)
	map:SetBackgroundColor(Color(100,100,100))
	map:MakeDroppable("nzu_logicmap")
	map.Paint = function(s)
		local ply = LocalPlayer()
		local pos = ply:GetPos()
		local x,y = s:GetAbsoluteFramePosition(pos.x,pos.y)

		surface.SetMaterial(playermat)
		surface.SetDrawColor(255,255,255)
		surface.DrawTexturedRectRotated(x-25,y-25,50,50,ply:GetAngles()[2])
	end

	local mapcontrol = panel:Add("DPanel")
	mapcontrol:SetTall(50)
	mapcontrol:DockPadding(5,5,5,5)

	local snaptoply = mapcontrol:Add("DButton")
	snaptoply:SetWide(40)
	snaptoply:Dock(RIGHT)
	snaptoply:SetText("Snap")
	snaptoply.DoClick = function(s)
		local p = LocalPlayer():GetPos()
		map:SnapTo(p.x,p.y)
	end

	panel.PerformLayout = function(s)
		local w,w2 = s:GetWide(), mapcontrol:GetWide()
		mapcontrol:SetPos(w - toolbarwidth - w2, 0)
	end

	logicmap = map
	for k,v in pairs(nzu.GetAllLogicUnits()) do
		addunittomap(v)
	end
end, "icon16/arrow_switch.png", "Create and connect Config Logic")

hook.Add("nzu_LogicUnitCreated", "nzu_LogicMapCreate", function(u) addunittomap(u) end)