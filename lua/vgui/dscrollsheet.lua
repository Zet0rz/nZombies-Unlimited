
local PANEL = {}

AccessorFunc(PANEL, "m_iDragPositions", "DragPositions")

AccessorFunc(PANEL, "m_iMinX", "MinX")
AccessorFunc(PANEL, "m_iMaxX", "MaxX")
AccessorFunc(PANEL, "m_iMinY", "MinY")
AccessorFunc(PANEL, "m_iMaxY", "MaxY")
AccessorFunc(PANEL, "m_iSizePadding", "SizePadding")
AccessorFunc(PANEL, "m_iSizeScale", "SizeScale")

function PANEL:Init()
	self.Panels = {}
	self:SetMaxX(1000)
	self:SetMinX(-1000)
	self:SetMaxY(1000)
	self:SetMinY(-1000)
	self:SetSizePadding(0) -- Additional space around the map's edges
	self:SetSizeScale(1)

	self.Canvas = self:AddNonCanvas("DPanel")
	--self.Canvas:SetParent(self)
	self.Canvas:SetSize(1000, 1000)
	self.Canvas.OnModified = function() self:OnDragModified() end
	--self.Canvas:Droppable("scrollsheet_canvas")
	
	self.Canvas.OnMousePressed = function(s,c) self:OnMousePressed(c) end
	self.Canvas.OnMouseReleased = function(s,c) self:OnMouseReleased(c) end
	
	self.Canvas.PerformLayout = function(s)
		
	end
	self.Canvas.Paint = function(s)
		
	end
	
	self.Controls = self:AddNonCanvas("DPanel")
	self.Controls:SetWidth(100)
	self.Controls:DockPadding(5,5,5,5)
	self.Controls:Dock(RIGHT)
	self.Controls.Paint = function(s) end
	
	--[[self.ZoomIn = self:AddControl("DButton")
	self.ZoomIn:SetText("+")
	--self.ToCenter:SetSize(50,50)
	self.ZoomIn:Dock(TOP)
	self.ZoomIn.DoClick = function()
		self:SetScale(self:GetScale()*2)
	end
	
	self.ZoomOut = self:AddControl("DButton")
	self.ZoomOut:SetText("-")
	--self.ToCenter:SetSize(50,50)
	self.ZoomOut:Dock(TOP)
	self.ZoomOut.DoClick = function()
		self:SetScale(self:GetScale()/2)
	end]]
	
	self.ToCenter = self:AddControl("DButton")
	self.ToCenter:SetText("Center")
	--self.ToCenter:SetSize(50,50)
	self.ToCenter:Dock(TOP)
	self.ToCenter.DoClick = function()
		self:SnapTo(0,0)
	end
	
	self:UpdateCanvasSize()
	self:SnapTo(0,0)
end

function PANEL:AddControl(p)
	return self.Controls:Add(p)
end

function PANEL:AddNonCanvas(p)
	self.IGNORECHILD = true
	local n = self:Add(p)
	self.IGNORECHILD = nil
	return n
end

function PANEL:PerformLayout()
	if self.TOREBUILD then self:Rebuild() end
end

function PANEL:SetScale(num)
	self:SetSizeScale(num)
	local tx,ty = self:GetCenterPos()
	self.TOREBUILD = true
	self:InvalidateLayout()
	self:SnapTo(tx,ty)
end

function PANEL:GetScale()
	return self:GetSizeScale()
end

function PANEL:MakeDroppable(str) 
	--self.Canvas:Droppable(str)
	self.Canvas:Receiver(str, function(s,pnls, dropped, menu, x, y) self:DropAction(pnls, dropped, menu, x, y) end)
	self:Receiver(str, self.DropAction)
end

function PANEL:GetLocalPosition(x,y)
	local pad = self:GetSizePadding()
	local tx = x/self:GetScale() - pad + self:GetMinX()
	local ty = self:GetMaxY() - (y/self:GetScale() - pad)

	return tx,ty
end
function PANEL:GetAbsolutePosition(x,y)
	local pad = self:GetSizePadding()
	local tx = x - self:GetMinX()
	local ty = self:GetMaxY() - y

	return tx*self:GetScale() + pad,ty*self:GetScale() + pad
end

function PANEL:DropAction(pnls, dropped, menu, x, y)
	if dropped then
		local tx,ty = self:GetLocalPosition(self.Canvas:LocalCursorPos())
		for k,v in pairs(pnls) do
			self:SetChildPos(v,tx,ty)
		end
	end
end

function PANEL:OnChildAdded(p)
	if not self.IGNORECHILD then
		p:SetParent(self.Canvas)
		local x,y = p:GetPos()
		self:SetChildPos(p,self:GetLocalPosition(x + p:GetWide()/2, y + p:GetTall()/2))
	end
end

function PANEL:OnChildRemoved(p)
	self.Panels[p] = nil
end

function PANEL:SetChildPos(p, x,y)
	self.Panels[p] = {x,y}
	
	if x > self:GetMaxX() then self:SetMaxX(x) elseif x < self:GetMinX() then self:SetMinX(x) end
	if y > self:GetMaxY() then self:SetMaxY(y) elseif y < self:GetMinY() then self:SetMinY(y) end
	
	--self.ToMove[p] = true
	self.TOREBUILD = true
	self:InvalidateLayout()
end

function PANEL:Rebuild()	
	local tx,ty = self:GetCenterPos()
	
	-- Resize to fit outermost children
	local pad = self:GetSizePadding()
	local scale = self:GetScale()
	local x = (self:GetMaxX() - self:GetMinX())*scale + pad*2
	local y = (self:GetMaxY() - self:GetMinY())*scale + pad*2
	self.Canvas:SetSize(x,y)
	
	for k,v in pairs(self.Panels) do
		local tx,ty = self:GetAbsolutePosition(unpack(v))
		k:SetPos(tx - k:GetWide()/2 + pad, ty - k:GetTall()/2 + pad)
	end
	
	self:SnapTo(tx,ty) -- Post scale/resize, snap to same position
	self.TOREBUILD = false
end

-- Moves the canvas so that the center is x,y in local coordinates
function PANEL:SnapTo(x,y)
	local w,h = self:GetWide()/2, self:GetTall()/2
	local cx,cy = self:GetAbsolutePosition(x,y)
	
	self.Canvas:SetPos(-cx + w, -cy + h)
end

-- Returns what local coordinate is at the center of the panel
function PANEL:GetCenterPos()
	local w,h = self:GetWide()/2, self:GetTall()/2
	local cx,cy = self.Canvas:GetPos()
	local tx,ty = self:GetLocalPosition(w - cx, h - cy)
	
	return tx,ty
end

function PANEL:UpdateCanvasSize()
	--[[local torebuild = false
	local cx,cy = self.Canvas:GetPos()
	local w,h = self:GetSize()
	print(cx,cy, w, h, (w - self.Canvas:GetWide()), (h - self.Canvas:GetTall()))
	if cx > 0 then
		print("Can see left edge")
		self:SetMinX(self:GetMinX() - w*self:GetScale())
		torebuild = true
	end
	if cy > 0 then
		print("Can see top edge")
		self:SetMinY(self:GetMinY() - h*self:GetScale())
		torebuild = true
	end
	if cx < (w - self.Canvas:GetWide()) then
		print("Can see right edge")
		self:SetMaxX(self:GetMaxX() + w*self:GetScale())
		torebuild = true
	end
	if cy < (h - self.Canvas:GetTall()) then
		print("Can see bottom edge")
		self:SetMaxY(self:GetMaxY() + h*self:GetScale())
		torebuild = true
	end]]
end

-- Support dragging the panel itself to move around
function PANEL:StartDrag(x,y)
	local x2,y2 = self.Canvas:GetPos()
	self:SetDragPositions({x2,y2,x,y})
end
function PANEL:EndDrag(x,y)
	local drag = self:GetDragPositions()
	if drag then
		if x and y then
			local x,y = gui.MousePos()
			local tx = drag[1] + (x - drag[3])
			local ty = drag[2] + (y - drag[4])
		
			self.Canvas:SetPos(tx,ty)
		end
		self:SetDragPositions(nil)
		self:UpdateCanvasSize()
	end
	self:MouseCapture(false)
end
function PANEL:Think()
	local drag = self:GetDragPositions()
	
	if drag then
		local x,y = gui.MousePos()
		local tx = drag[1] + (x - drag[3])
		local ty = drag[2] + (y - drag[4])
		
		self.Canvas:SetPos(tx,ty)
	end
end

function PANEL:OnMousePressed(code)
	if code == MOUSE_LEFT then
		self:StartDrag(gui.MousePos())
		self:MouseCapture(true)
	end
end
function PANEL:OnMouseReleased(code)
	if code == MOUSE_LEFT then
		self:EndDrag()
	end
end
function PANEL:OnCursorExited()
	self:EndDrag()
end

derma.DefineControl( "DScrollSheet", "", PANEL, "DPanel" )

--[[timer.Simple(1, function()
	local frame = vgui.Create("DFrame")
	frame:SetSize( 500, 500 )
	frame:Center()
	frame:MakePopup()

	local dragbase = vgui.Create("DScrollSheet", frame)
	dragbase:Dock(FILL)
	dragbase:MakeDroppable("test")
	dragbase:SetBackgroundColor(Color(255,0,0))

	for i = 0, 10 do
		local butt = dragbase:Add("DButton")
		butt:SetPos(0,0)
		butt:SetSize(50,50)
		dragbase:SetChildPos(butt, 0,0)
		butt:Droppable("test")
		butt.id = i
		butt:SetText(i)
	end
end)]]