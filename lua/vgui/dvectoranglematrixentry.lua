
local PANEL = {}

function PANEL:Init()
	self.nX = self:Add("DNumberWang")
	self.nY = self:Add("DNumberWang")
	self.nZ = self:Add("DNumberWang")

	self.nX:SetMinMax(nil,nil)
	self.nY:SetMinMax(nil,nil)
	self.nZ:SetMinMax(nil,nil)

	self.m_vVector = Vector()

	self.nX.OnValueChanged = function(s,n) self.m_vVector.x = n end
	self.nY.OnValueChanged = function(s,n) self.m_vVector.y = n end
	self.nZ.OnValueChanged = function(s,n) self.m_vVector.z = n end
end

function PANEL:SetVector(v)
	local v = Vector(v.x, v.y, v.z)

	self.nX:SetValue(v.x)
	self.nY:SetValue(v.y)
	self.nZ:SetValue(v.z)

	self.m_vVector = v
end

function PANEL:SetMinMax(min,max)
	self.nX:SetMinMax(min,max)
	self.nY:SetMinMax(min,max)
	self.nZ:SetMinMax(min,max)
end

function PANEL:GetVector() return self.m_vVector end
PANEL.GetValue = PANEL.GetVector -- Alias

function PANEL:PerformLayout()
	local w,h = self:GetSize()
	local pad = 5

	local th = 20
	local tw = (w - pad)/3 - 2
	self.nX:SetSize(tw,th)
	self.nX:SetPos(0,0)
	self.nY:SetSize(tw,th)
	self.nY:SetPos(pad + tw, 0)
	self.nZ:SetSize(tw,th)
	self.nZ:SetPos(pad*2 + tw*2, 0)
end

derma.DefineControl( "DVectorEntry", "", PANEL, "Panel" )

local ANGLE = {}
function ANGLE:Init()
	self.nP = self:Add("DNumberWang")
	self.nY = self:Add("DNumberWang")
	self.nR = self:Add("DNumberWang")

	self.nP:SetMinMax(nil,nil)
	self.nY:SetMinMax(nil,nil)
	self.nR:SetMinMax(nil,nil)

	self.m_aAngle = Angle()

	self.nP.OnValueChanged = function(s,n) self.m_aAngle.p = n end
	self.nY.OnValueChanged = function(s,n) self.m_aAngle.y = n end
	self.nR.OnValueChanged = function(s,n) self.m_aAngle.r = n end
end

function ANGLE:SetAngles(a)
	local a = Angle(a.p, a.y, a.r)

	self.nP:SetValue(a.p)
	self.nY:SetValue(a.y)
	self.nR:SetValue(a.r)

	self.m_aAngle = a
end

function ANGLE:GetAngles() return self.m_aAngle end
ANGLE.GetValue = ANGLE.GetAngles -- Alias

function ANGLE:PerformLayout()
	local w,h = self:GetSize()
	local pad = 5

	local th = 20
	local tw = (w - pad)/3 - 2
	self.nP:SetSize(tw,th)
	self.nP:SetPos(0,0)
	self.nY:SetSize(tw,th)
	self.nY:SetPos(pad + tw, 0)
	self.nR:SetSize(tw,th)
	self.nR:SetPos(pad*2 + tw*2, 0)
end
derma.DefineControl( "DAngleEntry", "", ANGLE, "Panel" )

local MATRIX = {}
function MATRIX:Init()
	self.m_mMatrix = Matrix()

	self.m_tNumberWangs = {}
	for i = 1,4 do
		self.m_tNumberWangs[i] = {}
		for j = 1,4 do
			self.m_tNumberWangs[i][j] = self:Add("DNumberWang")
			self.m_tNumberWangs[i][j].OnValueChanged = function(s,n) self.m_mMatrix:SetField(i,j,n) end
			self.m_tNumberWangs[i][j]:SetMinMax(nil,nil)
		end
	end
end

function MATRIX:SetMatrix(m)
	local m = Matrix(m:ToTable())
	for i = 1,4 do
		for j = 1,4 do
			self.m_tNumberWangs[i][j]:SetValue(m:GetField(i,j))
		end
	end

	self.m_mMatrix = m
end

function MATRIX:SetMinMax(min,max)
	for i = 1,4 do
		for j = 1,4 do
			self.m_tNumberWangs[i][j]:SetMinMax(min,max)
		end
	end
end

function MATRIX:GetMatrix() return self.m_mMatrix end
MATRIX.GetValue = MATRIX.GetMatrix -- Alias

function MATRIX:PerformLayout()
	local w,h = self:GetSize()
	local a,b,c,d = self:GetDockPadding()

	local th = 20
	local tw = (w - a)/4 - a
	
	for i = 1,4 do
		for j = 1,4 do
			self.m_tNumberWangs[i][j]:SetSize(tw,th)
			self.m_tNumberWangs[i][j]:SetPos(j*a + (j-1)*tw, i*a + (i-1)*th)
		end
	end
end
derma.DefineControl( "DMatrixEntry", "", MATRIX, "Panel" )