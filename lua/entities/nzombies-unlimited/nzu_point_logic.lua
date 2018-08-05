
local logic_meta = {
	GetEntity = function(self)
		return self.Entity
	end,
	GetConnections = function(self)
		return self.Entity.LOGIC_CONNECTIONS
	end,
	GetType = function(self)
		return self.Type
	end,
	GetID = function(self)
		return self.Entity.LOGIC_ID
	end,
	AcceptConnection = function(self, from, inp)
		return not not self.Inputs[inp]
	end,
	Input = function(self, inp, ...)
		if not self:AcceptInput(inp, ...) then return false end
	
		local f = self.Inputs[inp]
		if f then
			local result = f(self, ...)
			if result == nil then return true end -- No return = default it worked
			return result
		end
		return false
	end,
	Output = function(self, outp)
		local c = self:GetConnections()
		if c and c[outp] then
			for k,v in pairs(c[outp]) do
				if IsValid(k) then
					for k2,v2 in pairs(v) do
						v:Input(k2, table.unpack(v2))
					end
				end
			end
		end
	end,
	AcceptInput = function(self, inp, ...)
		return true -- Always allow inputs (that were connected)
	end,
	Connect = function(self, outp, targetid, inp, ...)
		local target = getlogicbyid(targetid)
		if IsValid(target) and target:AcceptConnection(self, inp) then
			local c = self:GetConnections()
			if not c then c = {} end
			
			if not c[outp] then c[outp] = {} end
			if not c[outp][target] then c[outp][targetid] = {} end
			c[outp][targetid][inp] = {...}
			
			return true
		else
			return false
		end
	end,
	Disconnect = function(self, outp, targetid, inp)
		local c = self:GetConnections()
		if not c then return end
		if not c[outp] then return end
		if not c[outp][targetid] then return end
		c[outp][targetid][inp] = nil
		
		if #c[outp][targetid] <= 0 then c[outp][targetid] = nil end
		if #c[outp] <= 0 then c[outp] = nil end
	end,
	IsValid = function(self) return self.Entity and IsValid(self.Entity) end,
	
	-- Called to update the panel (such as size, connection points etc.)
	UpdatePanel = function(self, panel)
		self:GeneratePanel(panel)
	end,
	
	-- Override this if you want custom colors or sizes
	GeneratePanel = function(self, panel)
		local linegaps = 5
		local height = 50
		local num = math.Max(#self.Inputs, #self.Outputs)
		height = math.Max(height, num*5)
		
		panel:SetHeight(height)
		panel.Icon = panel.Icon or panel:Add("DImage")
		panel.Icon:SetSize(40,40)
		panel.Icon:SetPos(5, height/2 - 20)
		panel.Icon:SetImage(self.Icon)
		
		panel.InputPositions = {}
		local i = 1
		for k,v in pairs(self.Inputs) do
			panel.InputPositions[k] = linegaps*i
			i = i + 1
		end
		
		panel.OutputPositions = {}
		i = 1
		for k,v in pairs(self.Outputs) do
			panel.OutputPositions[v] = linegaps*i
			i = i + 1
		end
	end
	
	Initialize = function(self) end,
	Think = function(self) end,
}
logic_meta.__index = logic_meta

local logictypes = {}
local oldlogic = LOGIC
for k,v in pairs(file.Find("nzombies-unlimited/logicentities/*.lua")) do
	LOGIC = {}
	setmetatable(LOGIC, logic_meta)
	
	if SERVER then AddCSLuaFile(v) end
	include(v)
	
	if LOGIC.Name then
		logictypes[LOGIC.Name] = LOGIC
		baseclass.Set("nzu_logic_"..LOGIC.Name)
	end
end
for k,v in pairs(logictypes) do
	-- Set metatables for inheritance
	if v.Base then
		local meta = logictypes[v.Base]
		if meta then
			local m = {} -- Make a metatable for this logic type
			m.__index = meta -- Make it point at our base logic type for undefined keys
			setmetatable(v,m)
		else
			Msg("ERROR: Trying to derive nZombies Unlimited Logic type "..v.Name.." from non-existant Logic type "..v.Base.."!\n" )
		end
	end
end
LOGIC = oldlogic or nil

ENT.Type = "point"
function ENT:Initialize()
	self:SetLogicType(self.LogicType)
	--self:SetLogicConnections({})
end

function ENT:SetupDataTables()
	
end

function ENT:OnDuplicated(data)
	
end

function ENT:Think()
	self.LOGIC_TABLE:Think()
end

function ENT:SetLogicType(logictype)
	self.LOGIC_TABLE = {
		Type = logictype,
		Entity = self,
	}
	
	setmetatable(self.LOGIC_TABLE, logictypes[logictype])
	self.LOGIC_TYPE = logictype
	
	duplicator.StoreEntityModifier(self, "nzu_logic_type", logictype)
	
	self.LOGIC_TABLE:Initialize()
end

function ENT:SetLogicConnections(tbl)
	self.LOGIC_CONNECTIONS = tbl
	duplicator.StoreEntityModifier(self, "nzu_logic_connections", tbl)
end

function ENT:SetLogicID(id)
	self.LOGIC_ID = id
	duplicator.StoreEntityModifier(self, "nzu_logic_id", id)
end

duplicator.RegisterEntityModifier("nzu_logic_connections", function(ply, ent, data)
	ent:SetLogicConnections(data)
end)
duplicator.RegisterEntityModifier("nzu_logic_type", function(ply, ent, data)
	ent:SetLogicType(data)
end)
duplicator.RegisterEntityModifier("nzu_logic_id", function(ply, ent, data)
	ent:SetLogicID(data)
end)