print("Yo")

local port_size = 10

local CONNECTION = {}
function CONNECTION:Init()
	self:SetSize(port_size,port_size)
	self:Droppable("nzu_logicmap_connection_in")
	self:SetPaintBackground(false)
end
function CONNECTION:PaintOver(x,y)
	if IsValid(self.Output) then
		surface.SetDrawColor(0,0,0)
		surface.DrawLine(self.GetPos(), self.Output:GetPos())
	end
end

function CONNECTION:SetPorts(outp, inp)
	self.Tail = outp.Panel
	self:SetParent(inp.Panel)
end

function CONNECTION:SetConnection(c)
	self.m_tConnection = c
end

function CONNECTION:PaintOver(x,y)
	if IsValid(self.Tail) then
		surface.SetDrawColor(0,0,0)
		DisableClipping(true)
		local tx,ty = self:ScreenToLocal(self.Tail:LocalToScreen(5,5))
		surface.DrawLine(tx,ty,x - 5,y - 5)
		DisableClipping(false)
	end
end

--[[function CONNECTION:OnMouseReleased(code)
	if not self:IsDragging() then
		print("I'm not here")
		self:Remove()
	end
end]]


local INPUTPORT = {}
function INPUTPORT:Init()
	self:SetBackgroundColor(Color(150,255,150))
	self:SetSize(port_size,port_size)

	self:Receiver("nzu_logicmap_connection", self.DropAction)
end

function INPUTPORT:DropAction(pnls, dropped, menu, x, y)
	if dropped then
		for k,v in pairs(pnls) do
			-- Request a connection
			net.Start("nzu_logicmap_connect")
				net.WriteUInt(v.m_lUnit:LogicIndex(), 16)
				net.WriteString(v.m_sPort)
				net.WriteUInt(self.m_lUnit:LogicIndex(), 16)
				net.WriteString(self.m_sPort)
				net.WriteString("") -- For now, no arguments. Maybe change later so client can "pre-send" args?
			net.SendToServer()
		end
	end
end

local OUTPUTPORT = {}
function OUTPUTPORT:Init()
	self:SetBackgroundColor(Color(255,150,150))
	self:SetSize(port_size,port_size)

	self:Droppable("nzu_logicmap_connection")
end

local drawwiremouse
function OUTPUTPORT:OnMousePressed(code)
	--drawwiremouse = {500,500}
	--self:MouseCapture(true)
	self:DragMousePress(code)
end

function OUTPUTPORT:OnMouseReleased(code)
	--self:MouseCapture(false)
	drawwiremouse = nil
	self:DragMouseRelease(code)
end

function OUTPUTPORT:PaintOver(x,y)
	if self:IsDragging() then
		surface.SetDrawColor(0,0,0)
		local mx,my = self:LocalCursorPos()
		DisableClipping(true)
		surface.DrawLine(5,5,mx,my)
		DisableClipping(false)
	end
end

derma.DefineControl("DLogicMapUnitConnection", "", CONNECTION, "DPanel")
derma.DefineControl("DLogicMapUnitInput", "", INPUTPORT, "DPanel")
derma.DefineControl("DLogicMapUnitOutput", "", OUTPUTPORT, "DPanel")

local TYPE = {}
local createpanel = {
	[TYPE_STRING]		= function() local p = vgui.Create("DTextEntry") p:SetTall(40) return p end,
	[TYPE_NUMBER]		= function() local p = vgui.Create("Panel") p.N = p:Add("DNumberWang") p.N:Dock(FILL) p.N:SetMinMax(nil,nil) p:SetTall(40) return p end,
	[TYPE_BOOL]			= function() local p = vgui.Create("DCheckBoxLabel") p:SetText("Enabled") p:SetTall(50) p:SetTextColor(color_black) return p end,
	--[TYPE_ENTITY]		= function end,
	[TYPE_VECTOR]		= function() local p = vgui.Create("DVectorEntry") p:SetTall(30) return p end,
	[TYPE_ANGLE]		= function() local p = vgui.Create("DAngleEntry") p:SetTall(30) return p end,
	[TYPE_MATRIX]		= function() local p = vgui.Create("DMatrixEntry") p:SetTall(100) return p end,
	[TYPE_COLOR]		= function() return vgui.Create("DColorMixer") end,
}
local setvalue = {
	[TYPE_STRING]		= function(p,v) p:SetText(v or "") end,
	[TYPE_NUMBER]		= function(p,v) p.N:SetValue(v) end,
	[TYPE_BOOL]			= function(p,v) p:SetChecked(v) end,
	--[TYPE_ENTITY]		= function end,
	[TYPE_VECTOR]		= function(p,v) p:SetVector(v) end,
	[TYPE_ANGLE]		= function(p,v) p:SetAngles(v) end,
	[TYPE_MATRIX]		= function(p,v) p:SetMatrix(v) end,
	[TYPE_COLOR]		= function(p,v) p:SetColor(v) end,
}
local getvalue = {
	[TYPE_STRING]		= function(p) return p:GetText() end,
	[TYPE_NUMBER]		= function(p) return p.N:GetValue() end,
	[TYPE_BOOL]			= function(p) return p:GetChecked() end,
	--[TYPE_ENTITY]		= function end,
	[TYPE_VECTOR]		= function(p) return p:GetVector() end,
	[TYPE_ANGLE]		= function(p) return p:GetAngles() end,
	[TYPE_MATRIX]		= function(p) return p:GetMatrix() end,
	[TYPE_COLOR]		= function(p) local c = p:GetColor() return Color(c.r,c.g,c.b,c.a) end,
}

-- These are here temporarily; We will move files around so it becomes shared/nZombies/Sandbox separated files
local writetypes = {
	[TYPE_STRING]		= function ( v )	net.WriteString( v )		end,
	[TYPE_NUMBER]		= function ( v )	net.WriteDouble( v )		end,
	[TYPE_TABLE]		= function ( v )	net.WriteTable( v )			end,
	[TYPE_BOOL]			= function ( v )	net.WriteBool( v ) 			end,
	[TYPE_ENTITY]		= function ( v )	net.WriteEntity( v )		end,
	[TYPE_VECTOR]		= function ( v )	net.WriteVector( v )		end,
	[TYPE_ANGLE]		= function ( v )	net.WriteAngle( v )			end,
	[TYPE_MATRIX]		= function ( v )	net.WriteMatrix( v )		end,
	[TYPE_COLOR]		= function ( v )	net.WriteColor( v )			end,
}

local SETTINGS = {}
function SETTINGS:SetUnit(u)
	if not IsValid(self.TopPanel) then
		self.TopPanel = self:Add("Panel")
		self.TopPanel:Dock(TOP)
		self.TopPanel:SetTall(30)
	end

	if not IsValid(self.SaveAll) then
		self.SaveAll = self.TopPanel:Add("DButton")
		self.SaveAll:Dock(RIGHT)
		self.SaveAll:SetWide(60)
		self.SaveAll:SetText("Save all")
		self.SaveAll:DockMargin(5,5,5,5)
		self.SaveAll.DoClick = function(s)
			for k,v in pairs(self.Settings) do v._Save() end
		end
	end

	if not IsValid(self.ReloadAll) then
		self.ReloadAll = self.TopPanel:Add("DButton")
		self.ReloadAll:Dock(RIGHT)
		self.ReloadAll:SetWide(60)
		self.ReloadAll:SetText("Reload All")
		self.ReloadAll:DockMargin(5,5,0,5)
		self.ReloadAll.DoClick = function(s)
			self:Reload()
		end
	end

	if not IsValid(self.Name) then
		self.Name = self.TopPanel:Add("DLabel")
		self.Name:Dock(TOP)
		self.Name:SetContentAlignment(4)
		self.Name:SetTextColor(color_black)
		self.Name:SetTextInset(5,0)
	end
	self.Name:SetText(u.Name or "[No Name]")
	self.Name:SizeToContents()

	if not IsValid(self.Class) then
		self.Class = self.TopPanel:Add("DLabel")
		self.Class:SetContentAlignment(4)
		self.Class:Dock(TOP)
		self.Class:SetTextColor(color_black)
		self.Class:SetTextInset(5,0)
	end
	self.Class:SetText(tostring(u))
	self.Class:SizeToContents()
	
	if not IsValid(self.Categories) then
		self.Categories = self:Add("DCategoryList")
		self.Categories:Dock(FILL)
	else
		self.Categories:Clear()
	end

	self.Settings = {}
	for k,v in pairs(u.Settings) do
		local panel
		if v.CustomPanel then
			panel = v.CustomPanel.Create()
			v.CustomPanel.Set(panel, u:GetLogicSetting(k))
			panel._GetValue = v.CustomPanel.Get
			panel._SetValue = v.CustomPanel.Set
		elseif v.Type and createpanel[v.Type] then
			panel = createpanel[v.Type]()
			setvalue[v.Type](panel, u:GetLogicSetting(k))
			panel._GetValue = getvalue[v.Type]
			panel._SetValue = setvalue[v.Type]
		end

		if panel then
			panel._Save = function()
				net.Start("nzu_logicmap_setting")
					net.WriteUInt(u:LogicIndex(), 16)
					u:NetWriteLogicSetting(k, panel:_GetValue())
				net.SendToServer()
			end

			local cat = self.Categories:Add(k)
			cat:SetTall(panel:GetTall())
			cat:SetExpanded(true)
			cat:SetContents(panel)
			cat:DockMargin(0,0,0,1)

			local save = cat.Header:Add("DButton")
			save:Dock(RIGHT)
			save:DockMargin(2,2,2,2)
			save:SetWide(50)
			save:SetText("Save")
			save.DoClick = panel._Save

			self.Settings[k] = panel
		end
	end

	self.m_lUnit = u
end

function SETTINGS:Reload()
	if not self.Settings or not IsValid(self.m_lUnit) then return end
	for k,v in pairs(self.Settings) do
		v:_SetValue(self.m_lUnit:GetLogicSetting(k))
	end
end
derma.DefineControl("DLogicMapSettingsPanel", "", SETTINGS, "DPanel")

local PANEL = {}
AccessorFunc(PANEL,"m_bDisplayPorts", "ShowPorts", FORCE_BOOL)

function PANEL:Init()
	--self:SetPaintBackground(false)

	self.IGNORECHILD = true
	self.LeftPorts = self:Add("Panel")
	self.LeftPorts:SetWide(port_size)
	self.LeftPorts:Dock(LEFT)

	self.RightPorts = self:Add("Panel")
	self.RightPorts:Dock(RIGHT)
	self.RightPorts:SetWide(port_size)

	self.TopPorts = self:Add("Panel")
	self.TopPorts:Dock(TOP)
	self.TopPorts:SetTall(port_size)

	self.BottomPorts = self:Add("Panel")
	self.BottomPorts:Dock(BOTTOM)
	self.BottomPorts:SetTall(port_size)

	--self:DockPadding(port_size,port_size,port_size,port_size) -- The boundaries for logic ports
	self.ChipCanvas = self:Add("Panel")
	self.ChipCanvas:Dock(FILL)
	self.ChipCanvas:SetMouseInputEnabled(false)

	self.SettingsButton = vgui.Create("DImageButton", self.RightPorts)
	self.SettingsButton:SetImage("icon16/cog.png")
	self.SettingsButton:SetSize(port_size, port_size)
	self.SettingsButton:Dock(TOP)
	self.SettingsButton:SetZPos(100)
	self.SettingsButton.DoClick = function() self:OpenSettings() end

	self.EntityIcon = vgui.Create("DImage", self.TopPorts)
	self.EntityIcon:SetImage("icon16/bricks.png")
	self.EntityIcon:SetSize(port_size, port_size)
	self.EntityIcon:Dock(RIGHT)
	self.EntityIcon:SetZPos(100)
	self.EntityIcon:SetVisible(false)

	self.IGNORECHILD = nil

	self.m_tOutputPorts = {}
	self.m_tInputPorts = {}
end

function PANEL:AddNonCanvas(p)
	self.IGNORECHILD = true
	local n = self:Add(p)
	self.IGNORECHILD = nil
	return n
end

function PANEL:OnChildAdded(p)
	if not self.IGNORECHILD then
		p:SetParent(self.ChipCanvas)
		p:SetDragParent(self)
	end
end

function PANEL:SetLogicUnit(unit)
	local chip = unit.nzu_Logic or unit
	if chip.CustomPanel then
		self:Clear()
		chip.CustomPanel(unit, self)
	else
		if not self.Icon then self.Icon = self:Add("DImage") end
		self.Icon:SetImage(chip.Icon)
		--self.Icon:Dock(FILL)
		--self.Icon:DockMargin(10,10,10,10)
		self.Icon:SetKeepAspect(true)
	end
	self.m_lUnit = unit

	-- Update the ports
	for k,v in pairs(self.m_tOutputPorts) do if IsValid(v.Panel) then v.Panel:Remove() end end
	for k,v in pairs(self.m_tInputPorts) do if IsValid(v.Panel) then v.Panel:Remove() end end
	self.m_tOutputPorts = {}
	self.m_tInputPorts = {}

	local outputs = unit:GetLogicOutputs()
	if outputs then
		for k,v in pairs(outputs) do
			if v.Port then
				self.m_tOutputPorts[k] = {Side = v.Port.Side, Pos = v.Port.Pos}
			end
		end
	end
	local inputs = unit:GetLogicInputs()
	if inputs then
		for k,v in pairs(inputs) do
			if v.Port then
				self.m_tInputPorts[k] = {Side = v.Port.Side, Pos = v.Port.Pos}
			end
		end
	end

	self:UpdatePorts()
end

function PANEL:OpenSettings()
	if not IsValid(self.SettingsFrame) then
		self.SettingsFrame = vgui.Create("DFrame", self:GetParent())
		self.SettingsFrame:SetTitle(tostring(self.m_lUnit))

		local settings = self.SettingsFrame:Add("DLogicMapSettingsPanel")
		settings:SetUnit(self.m_lUnit)
		settings:Dock(FILL)

		self.SettingsFrame:SetDeleteOnClose(true)
		self.SettingsFrame:SetZPos(200)
		self.SettingsFrame:SetSize(300,500)

		self.SettingsPanel = settings
	end
	self.SettingsFrame:SetVisible(true)

	local x,y = self:GetPos()
	self.SettingsFrame:SetPos(x,y)
end

function PANEL:PerformLayout()
	if IsValid(self.Icon) then
		local x,y = self.ChipCanvas:GetSize()
		local min = math.Min(x,y)
		self.Icon:SetSize(min,min)
		self.Icon:SetPos(x/2 - min/2, y/2 - min/2)
	end
end

function PANEL:OnRemove()
	if IsValid(self.SettingsFrame) then self.SettingsFrame:Remove() end
end

function PANEL:Think()
	if IsValid(self.m_bThinkPosition) then
		local pos = self.m_lUnit:GetPos()
		self.m_bThinkPosition:SetChildPos(self, pos.x, pos.y)
	end
end

local postypes = {
	[LEFT] = function(s,p,x) p:SetParent(s.LeftPorts) p:SetPos(0,x) end,
	[RIGHT] = function(s,p,x) p:SetParent(s.RightPorts) p:SetPos(0,x) end,
	[TOP] = function(s,p,x) p:SetParent(s.TopPorts) p:SetPos(x,0) end,
	[BOTTOM] = function(s,p,x) p:SetParent(s.BottomPorts) p:SetPos(x,0) end,
}
local function doport(self, name, inout, side, pos)
	local port
	if inout then
		if not self.m_tInputPorts[name] then self.m_tInputPorts[name] = {} end
		port = self.m_tInputPorts[name]
	else
		if not self.m_tOutputPorts[name] then self.m_tOutputPorts[name] = {} end
		port = self.m_tOutputPorts[name]
	end
	local panel = port and port.Panel or vgui.Create(inout and "DLogicMapUnitInput" or "DLogicMapUnitOutput")
	panel.m_lUnit = self.m_lUnit
	panel.m_sPort = name

	postypes[side](self, panel, pos)
	--panel:SetPortSide(side)

	--[[local name = self:AddNonCanvas("DLabel")
	name:SetText(name)
	name:SetVisible(false)
	name:DisableClipping(true)]]

	port.Side = side
	port.Pos = pos
	port.Connections = port.Connections or {}
	port.Panel = panel
end
function PANEL:UpdatePorts()
	if self:GetShowPorts() then
		for k,v in pairs(self.m_tInputPorts) do
			doport(self, k, true, v.Side, v.Pos)
		end

		for k,v in pairs(self.m_tOutputPorts) do
			doport(self, k, false, v.Side, v.Pos)
		end
	else
		for k,v in pairs(self.m_tInputPorts) do if IsValid(v.Panel) then v.Panel:Remove() end end
		for k,v in pairs(self.m_tOutputPorts) do if IsValid(v.Panel) then v.Panel:Remove() end end
	end
	self.SettingsButton:SetVisible(self:GetShowPorts())
end

function PANEL:AddOutputPort(name, side, pos)
	doport(self, name, false, side, pos)
end

function PANEL:AddInputPort(name, side, pos)
	doport(self, name, true, side, pos)
end

function PANEL:OnDropIntoMap(x,y)
	-- Override me!
end
derma.DefineControl("DLogicMapUnit", "", PANEL, "DPanel")

local logicmapchips = {}
local logicmapconnections = {}

local MAP = {}
local ssheet = baseclass.Get("DScrollSheet")
local playermat = Material("icon16/arrow_right.png") -- Change this
function MAP:Init()
	ssheet.Init(self)
	self:MakeDroppable("nzu_logicmap")

	--[[self.Canvas.PaintOver = function(s,x,y)
		if drawwiremouse then
			surface.SetDrawColor(0,0,0)
			local mx,my = s:LocalCursorPos()
			surface.DrawLine(unpack(drawwiremouse), mx,my)
		end
	end]]
end
function MAP:Paint(x,y)
	local ply = LocalPlayer()
	local pos = ply:GetPos()
	local x,y = self:GetAbsoluteFramePosition(pos.x,pos.y)

	surface.SetMaterial(playermat)
	surface.SetDrawColor(255,255,255)
	surface.DrawTexturedRectRotated(x-25,y-25,50,50,ply:GetAngles()[2])
end
derma.DefineControl("DLogicMap", "", MAP, "DScrollSheet")

local logicmap
local addunittomap
local function addconnection(unit, outp, cid, c, chip)
	local outputport = chip.m_tOutputPorts[outp]
	if outputport then
		if outputport.Connections[cid] then return end -- It already exists. Maybe update?
		local target = c.Target
		if not IsValid(target) then return elseif not logicmapchips[target:LogicIndex()] then addunittomap(target) end

		local inputport = logicmapchips[target:LogicIndex()].m_tInputPorts[c.Input]
		if inputport then
			local p = vgui.Create("DLogicMapUnitConnection", logicmap)
			p:SetPorts(outputport, inputport)
			p:SetConnection(c)
		end		
	end
end
addunittomap = function(unit)
	if IsValid(logicmapchips[unit:LogicIndex()]) then return end

	if IsValid(logicmap) then
		print(unit:LogicIndex())
		local chip = vgui.Create("DLogicMapUnit", logicmap)
		chip:SetShowPorts(true)
		chip:SetLogicUnit(unit)
		chip:SetSize(50,50)
		local pos = unit:GetPos()
		logicmap:SetChildPos(chip, pos.x,pos.y)

		if type(unit) == "Entity" then
			chip.m_bThinkPosition = logicmap
			chip.EntityIcon:SetVisible(true)
		else
			chip:Droppable("nzu_logicmap")
			chip.OnDropIntoMap = function(x,y)
				net.Start("nzu_logicmap_move")
					net.WriteUInt(unit:LogicIndex(), 16)
					net.WriteVector(Vector(x,y,0))
				net.SendToServer()
			end
		end

		logicmapchips[unit:LogicIndex()] = chip

		for k,v in pairs(unit:GetLogicOutputConnections()) do
			for k2,v2 in pairs(v) do
				addconnection(unit, k, k2, v2, chip)
			end
		end
	end
end

nzu.AddSpawnmenuTab("Logic Map", "DPanel", function(panel)
	--panel:SetSkin("nZombies Unlimited")
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

	local map = panel:Add("DLogicMap")
	map:Dock(FILL)
	map:SetBackgroundColor(Color(100,100,100))

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

hook.Add("nzu_LogicUnitCreated", "nzu_LogicMapCreate", addunittomap)
hook.Add("nzu_LogicUnitConnected", "nzu_LogicMapConnected", function(u, outp, cid, c)
	local chip = logicmapchips[u:LogicIndex()]
	if not chip then addunittomap(u) end
	addconnection(u, outp, cid, c, chip)
end)

hook.Add("nzu_LogicUnitSettingChanged", "nzu_LogicMapSetting", function(u, setting, val)
	local chip = logicmapchips[u:LogicIndex()]
	if chip and chip.SettingsPanel then
		local p = chip.SettingsPanel.Settings[setting]
		p:_SetValue(val)
	end
end)

hook.Add("nzu_LogicEntityCreated", "nzu_LogicMapCreate", addunittomap)

local function removeunit(unit)
	if logicmapchips[unit:LogicIndex()] then logicmapchips[unit:LogicIndex()]:Remove() end
end
hook.Add("nzu_LogicUnitRemoved", "nzu_LogicMapRemove", removeunit)
hook.Add("nzu_LogicEntityRemoved", "nzu_LogicMapRemove", removeunit)