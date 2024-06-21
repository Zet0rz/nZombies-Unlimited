
local PANEL = {}

function PANEL:Init()
	self.Panels = {}
	self.m_iTopLeftX = 0 -- This is negative
	self.m_iTopLeftY = 0 -- This is positive (y = up)

	self.Canvas = self:AddNonCanvas("Panel")
	self.Canvas.OnMousePressed = function(s,c) self:OnMousePressed(c) end
	self.Canvas.OnMouseReleased = function(s,c) self:OnMouseReleased(c) end
	self.Canvas.PerformLayout = function(c)
		--c:SizeToChildren(true,true)
	end
	
	self.m_iScale = 0.1 -- 0.1 pixels per unit
	self:SetCanvasSize(10000,10000,10000,10000) -- 10,000 units in all directions
	timer.Simple(0.05, function()
		self:SnapTo(0,0)
	end)
end
function PANEL:GetScale() return self.m_iScale end
function PANEL:SetScale(x)
	self.m_iScale = x
	self:Rebuild()
end
function PANEL:AddNonCanvas(p)
	self.IGNORECHILD = true
	local n = self:Add(p)
	self.IGNORECHILD = nil
	return n
end

function PANEL:OnChildAdded(p)
	if not self.IGNORECHILD then
		p:SetParent(self.Canvas)
	end
end

function PANEL:GetLocalPosition(x,y)
	local tx = x/self:GetScale() + self.m_iTopLeftX
	local ty = self.m_iTopLeftY - y/self:GetScale()

	return tx,ty
end
function PANEL:GetAbsolutePosition(x,y)
	local tx = x - self.m_iTopLeftX
	local ty = self.m_iTopLeftY - y

	return tx*self:GetScale(),ty*self:GetScale()
end

function PANEL:GetAbsoluteFramePosition(x,y)
	local tx,ty = self:GetAbsolutePosition(x,y)
	local cx,cy = self.Canvas:GetPos()
	return tx+cx, ty+cy
end

function PANEL:DropAction(pnls, dropped, menu, x, y)
	if dropped then
		local tx,ty = self:GetLocalPosition(self.Canvas:LocalCursorPos())
		for k,v in pairs(pnls) do
			if v.OnDrop then v = v:OnDrop() end
			if IsValid(v) then
				if not v.OnDropIntoMap or not v:OnDropIntoMap(tx,ty) then
					self:SetChildPos(v,tx,ty)
					if v.OnMapPositionChanged then v:OnMapPositionChanged(tx,ty) end -- Call the callback
				end
			end
		end
	end
end

function PANEL:Rebuild()
	-- Rebuilds all children's positions
	local cx,cy = self:GetCenterPos()

	local scale = self:GetScale()
	self.Canvas:SetSize((-self.m_iTopLeftX + self.m_iBottomRightX)*scale, (self.m_iTopLeftY - self.m_iBottomRightY)*scale)
	for k,v in pairs(self.Panels) do
		local tx,ty = self:GetAbsolutePosition(unpack(v))
		tx = tx - k:GetWide()/2
		ty = ty - k:GetTall()/2

		k:SetPos(tx,ty)
	end

	self:SnapTo(cx,cy)
end

function PANEL:SetCanvasSize(lx,uy,rx,dy)
	self.m_iTopLeftX = -lx
	self.m_iTopLeftY = uy
	self.m_iBottomRightX = rx
	self.m_iBottomRightY = -dy
	self:Rebuild()
end

function PANEL:SetChildPos(p, x,y)
	self.Panels[p] = {x,y}
	
	local tx,ty = self:GetAbsolutePosition(x,y)
	local w,h = p:GetWide(), p:GetTall()
	tx = math.Clamp(tx - w/2, 0, self.Canvas:GetWide() - w)
	ty = math.Clamp(ty - h/2, 0, self.Canvas:GetTall() - h)
	p:SetPos(tx,ty)
	--self:InvalidateLayout()
end

function PANEL:MakeDroppable(str) 
	--self.Canvas:Droppable(str)
	self.Canvas:Receiver(str, function(s,pnls, dropped, menu, x, y) self:DropAction(pnls, dropped, menu, x, y) end)
	self:Receiver(str, self.DropAction)
end

-- Moves the canvas so that the center is x,y in local coordinates
function PANEL:SnapTo(x,y)
	local w,h = self:GetWide()/2, self:GetTall()/2
	local cx,cy = self:GetAbsolutePosition(x,y)
	self.Canvas:SetPos(w - cx, h - cy)
end

-- Returns what local coordinate is at the center of the panel
function PANEL:GetCenterPos()
	local w,h = self:GetWide()/2, self:GetTall()/2
	local cx,cy = self.Canvas:GetPos()
	local tx,ty = self:GetLocalPosition(w - cx, h - cy)
	
	return tx,ty
end

-- Support dragging the panel itself to move around
AccessorFunc(PANEL, "m_iDragPositions", "DragPositions")
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
		--self:UpdateCanvasSize()
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

	local dragbase = vgui.Create("DScrollSheet2", frame)
	dragbase:Dock(FILL)
	dragbase:MakeDroppable("test")
	dragbase:SetBackgroundColor(Color(255,0,0))

	for i = 0, 10 do
		local butt = dragbase:Add("DButton")
		butt:SetPos(0,0)
		butt:SetSize(50,50)
		--dragbase:SetChildPos(butt, 0,0)
		butt:Droppable("test")
		butt.id = i
		butt:SetText(i)
	end
end)]]