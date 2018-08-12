
local ENTITY = FindMetaTable("Entity")

local logicunits = {}
local createdlogics = {}
local function makelogic(class)
	if logicunits[class] then
		local unit = table.Copy(logicunits[class])
		unti.BaseClass = unit.Base and logicunits[unit.Base] or nil
		unit.ClassName = class
		unit.m_tOutputConnections = {}
		unit.m_tInputConnections = {}

		return unit
	end
end

local connection_metatable = {
	function Remove(self)

	end
}
if SERVER then
	util.AddNetworkString("nzu_logic_connection")

else

end
connection_metatable.__index = connection_metatable
local function makeconnection(self, outp, target, inp, args)
	local tbl = {From = self, Output = outp, Target = target, Input = inp, Args = args}
	return tbl
end

local logic_metatable = {
	-- Return position of the Logic unit; If it is entity-tied, it's that entity's position
	function GetPos(self)
		if IsValid(self.m_eTiedEntity) then return self.m_eTiedEntity:GetPos() end
		return self.m_vPos
	end,

	-- Enable/disable functionality. This freezes its think function.
	function Enable(self)
		self.m_bEnabled = true
	end,
	function Disable(self)
		self.m_bEnabled = false
	end,
	function IsEnabled(self)
		return self.m_bEnabled
	end,

	-- Entity-tying binds the unit to an entity and follows it around
	function GetTiedEntity(self)
		return self.m_eTiedEntity
	end,

	-- Fires an input into this logic unit letting you decide who to make responsible
	-- Args are normally given by the connection, varargs dynamically from the logic unit itself
	function Input(self, inp, activator, caller, args, ...)
		local f = self.Inputs and self.Inputs[inp]
		if f then
			local result = f(self, activator, caller, args, ...)
			if result == nil then return true end -- No return = default it worked
			return result
		end
		return false
	end,

	-- Fires an ouput on this entity, looping through all connections and activating them
	-- Passes itself as the activator, but chains the caller along (often a player)
	-- Optionally passes a set of varargs that can be read as dynamic args
	function Output(self, outp, caller, ...)
		local c = self:GetOutputConnections()
		if c and c[outp] then
			for k,v in pairs(c[outp]) do
				v.target:Input(v.input, self, caller, v.args, ...) -- Dynamic args (passed from the logic unit, optional)
			end
		end
	end,

	-- Disconnects a connection from an ouput
	-- Requires specifying what output to disconnect from and what id
	function Disconnect(self, outp, connectionid)
		local c = self:GetOutputConnections()
		if not c[outp] or not c[outp][connectionid] then return end
		
		-- We can't table.remove as it shifts the indexes of other entries down, which breaks their connectionid
		c[outp][connectionid] = nil
	end,

	-- Gets the table of connections
	function GetOutputConnections(self)
		return self.m_tOutputConnections
	end

	-- Expose this? Currently only used for internal removal upon destroy
	--[[function GetInputConnections(self)
		return self.m_tInputConnections
	end]]
}

if SERVER then
	util.AddNetworkString("nzu_logic_position")
	util.AddNetworkString("nzu_logic_creation")
	util.AddNetworkString("nzu_logic_entitytie")

	-- Set the position if this is a floating point unit; it's basically arbitrary
	-- Network it if appropriate (Sandbox)
	logic_metatable.SetPos = function(self, vector)
		if IsValid(self.m_eTiedEntity) then return end
		self.m_vPos = vector

		-- For now just network always; we'll change this later if needed
		if self.m_bNetwork then
			net.Start("nzu_logic_position")
				net.WriteUInt(self.m_iIndex, 16)
				net.WriteVector(vector)
			net.Broadcast()
		end
	end

	-- Internal function: Network its creation to all connected players
	logic_metatable.NetworkCreation = function(self)
		net.Start("nzu_logic_creation")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteBool(true)
			net.WriteString(self.ClassName)
		net.Broadcast()
	end

	-- Internal function: Network its removal to all connected players
	logic_metatable.NetworkRemoval = function(self)
		net.Start("nzu_logic_creation")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteBool(false)
		net.Broadcast()
	end

	logic_metatable.TieToEntity = function(self, ent)
		self.m_eTiedEntity = ent
		net.Start("nzu_logic_entitytie")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteBool(true)
			net.WriteEntity(ent)
		net.Broadcast()
	end
	logic_metatable.UntieEntity = function(self)
		if IsValid(self.m_eTiedEntity) then
			self:SetPos(self.m_eTiedEntity:GetPos())
		end
		self.m_eTiedEntity = nil
		net.Start("nzu_logic_entitytie")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteBool(false)
		net.Broadcast()
	end

	-- Destroy the logic unit, including all output and input connections
	logic_metatable.Destroy = function(self)
		-- Remove from all connections
		-- This doesn't need to be networked since the clients can just do the same
		for k,v in pairs(self.m_tOutputConnections) do
			v.Target.m_tInputConnections[v.InputID] = nil -- Remove all outputs from their target's input list
		end
		for k,v in pairs(self.m_tInputConnections) do
			v.From.m_tOutputConnections[v.OutputID] = nil -- Remove all inputs from their from's output list
		end

		net.Start("nzu_logic_creation")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteBool(false)
		net.Broadcast()
	end

	-- Creates a connection between an output on this to an input on another unit
	-- Defines what arguments this connection carries
	-- Returns connection ID (used to remove)
	logic_metatable.Connect = function(self, outp, target, inp, args)
		if target.Inputs[inp] then
			local c = self:GetOutputConnections()
			if not c[outp] then c[outp] = {} end
			local tbl = makeconnection(self, outp, target, inp, args)
			tbl.OutputID = table.insert(c[outp], tbl)
			tbl.InputID = table.insert(target.m_tInputConnections, tbl)
			tbl.m_iIndex = table.insert(createdconnections, tbl)

			net.Start("nzu_logic_connection")
				net.WriteUInt(tbl.m_iIndex, 16)
				net.WriteBool(true)

				net.WriteUInt(self.m_iIndex, 16)
				net.WriteString(outp)
				net.WriteUInt(target.m_iIndex, 16)
				net.WriteString(inp)

				for k,v in pairs(args) do
					net.WriteBool(true)
					net.WriteString(v)
				end
				net.WriteBool(false)
			net.Broadcast()

			return tbl.OutputID, tbl
		end
	end

else
	-- Receive networking around creation of logic units
	net.Receive("nzu_logic_creation", function()
		local index = net.ReadUInt(16)
		if net.ReadBool() then
			local class = net.ReadString()
			local unit = class and makelogic(class)
			if unit then
				createdlogics[index] = unit
			end
		else
			if createdlogics[index] then createdlogics[index]:Destroy() end
			createdlogics[index] = nil
		end
	end)

	-- Clientside SetPos only changes it locally until next update from server (like Entity:SetPos)
	logic_metatable.SetPos = function(self, vector)
		if IsValid(self.m_eTiedEntity) then return end
		self.m_vPos = vector
	end
	net.Receive("nzu_logic_position", function()
		local index = net.ReadUInt(16)
		local pos = net.ReadVector()
		local unit = createdlogics[index]
		if unit then unit:SetPos(pos) end
	end)

	-- Clientside entity tying; this will also be overriden next time the server networks its state
	logic_metatable.TieToEntity = function(self, ent)
		self.m_eTiedEntity = ent
	end
	logic_metatable.UntieEntity = function(self)
		if IsValid(self.m_eTiedEntity) then
			self:SetPos(self.m_eTiedEntity:GetPos())
		end
		self.m_eTiedEntity = nil
	end
	net.Receive("nzu_logic_entitytie", function()
		local index = net.ReadUInt(16)
		if net.ReadBool() then
			local ent = net.ReadEntity()
			if createdlogics[index] then logic_metatable.TieToEntity(createdlogics[index], ent) end
		else
			if createdlogics[index] then logic_metatable.Untie(createdlogics[index]) end
		end
	end)
end
logic_metatable.__index = logic_metatable
-- Todo: Expose this table to FindMetaTable("nzu_Logic")?

-- This is based around the same system as the vgui system
local queuedregistration = {}
function nzu.RegisterLogicUnit(classname, LOGIC, base)
	LOGIC.Initialize = LOGIC.Initialize or function() end

	logicunits[classname] = LOGIC
	baseclass.Set(classname, LOGIC) -- So you can later baseclass.Get(classname)

	if LOGIC.Base then
		if logicunits[LOGIC.Base] then
			local meta = {}
			meta.__index = logicunits[LOGIC.Base]
			setmetatable(LOGIC, meta)
		else
			-- Queue setting the metatable as soon as that logic might be registered later
			if not queuedregistration[LOGIC.Base] then queuedregistration[LOGIC.Base] = {} end
			queuedregistration[LOGIC.Base][classname] = LOGIC

			setmetatable(LOGIC, logic_metatable)
		end
	else
		setmetatable(LOGIC, logic_metatable)
	end

	if queuedregistration[classname] then
		local meta = {}
		meta.__index = LOGIC

		-- Apply this LOGIC table as metatable for all other units based on this that happened to be registered before
		for k,v in pairs(queuedregistration[classname]) do
			setmetatable(v, meta)
		end

		queuedregistration[classname] = nil
	end

	return LOGIC
end

function nzu.CreateLogicUnit(class, nonetwork)
	local unit = makelogic(class)
	if unit then
		unit.m_iIndex = table.insert(createdlogics, unit)
		unit.m_bNetwork = not nonetwork

		if unit.m_bNetwork then unit:NetworkCreation() end

		-- We don't initialize it; it should only initialize when the actual game begins
		-- Likewise, Think doesn't run on it yet. The only thing that really works is positioning and settings

		return unit
	end
end