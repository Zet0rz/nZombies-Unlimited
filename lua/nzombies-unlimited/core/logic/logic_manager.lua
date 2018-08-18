
local ENTITY = FindMetaTable("Entity")

local logicunits = {}
local createdlogics = {}
local function makelogic(class)
	if logicunits[class] then
		local unit = table.Copy(logicunits[class])
		unit.BaseClass = unit.Base and logicunits[unit.Base] or nil
		unit.ClassName = class
		unit.m_vPos = Vector()
		unit.m_tOutputConnections = {}
		unit.m_tInputConnections = {}

		unit.m_tSettings = {}
		if unit.Settings then
			for k,v in pairs(unit.Settings) do
				unit.m_tSettings[k] = v.Default
			end
		end

		return unit
	end
end

-- Logic Connections as objects
--[[local connection_metatable = {
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
end]]

-- Logic Connections as lightweight tables
local function makeconnection(self, outp, target, inp, args)
	local tbl = {Target = target, Input = inp, Args = args}
	return tbl
end

local logic_metatable = {
	-- Return position of the Logic unit; If it is entity-tied, it's that entity's position
	GetPos = function(self)
		if IsValid(self.m_eTiedEntity) then return self.m_eTiedEntity:GetPos() end
		return self.m_vPos
	end,

	-- Enable/disable functionality. This freezes its think function.
	Enable = function(self)
		self.m_bEnabled = true
	end,
	Disable = function(self)
		self.m_bEnabled = false
	end,
	IsEnabled = function(self)
		return self.m_bEnabled
	end,

	-- Entity-tying binds the unit to an entity and follows it around
	GetTiedEntity = function(self)
		return self.m_eTiedEntity
	end,

	-- Fires an input into this logic unit letting you decide who to make responsible
	-- Args are normally given by the connection, varargs dynamically from the logic unit itself
	Input = function(self, inp, activator, caller, args, ...)
		local f = self.Inputs and self.Inputs[inp]
		if f and f.Function then
			local result = f.Function(self, activator, caller, args, ...)
			if result == nil then return true end -- No return = default it worked
			return result
		end
		return false
	end,

	-- Fires an ouput on this entity, looping through all connections and activating them
	-- Passes itself as the activator, but chains the caller along (often a player)
	-- Optionally passes a set of varargs that can be read as dynamic args
	Output = function(self, outp, caller, ...)
		local c = self:GetOutputConnections()
		if c and c[outp] then
			for k,v in pairs(c[outp]) do
				v.Target:Input(v.Input, self, caller, v.ActualArgs or v.Args, ...) -- Dynamic args (passed from the logic unit, optional)
			end
		end
	end,

	-- Gets the table of connections
	GetOutputConnections = function(self)
		return self.m_tOutputConnections
	end,

	-- Expose this? Currently only used for internal removal upon destroy
	--[[function GetInputConnections(self)
		return self.m_tInputConnections
	end,]]

	IsValid = function(self)
		return not self.m_bDestroyed
	end,

	GetSetting = function(self, setting)
		return self.m_tSettings[setting]
	end,

	Index = function(self) return self.m_iIndex end
}

if SERVER then
	local function writefullunit(self)
		net.WriteUInt(self.m_iIndex, 16)
		net.WriteBool(true)
		net.WriteString(self.ClassName)
		net.WriteVector(self:GetPos())

		if self.m_eTiedEntity then
			net.WriteBool(true)
			net.WriteEntity(self.m_eTiedEntity)
		else
			net.WriteBool(false)
		end
	end

	util.AddNetworkString("nzu_logic_position")
	util.AddNetworkString("nzu_logic_creation")
	util.AddNetworkString("nzu_logic_entitytie")
	util.AddNetworkString("nzu_logic_connection")
	util.AddNetworkString("nzu_logic_connection_setting")
	util.AddNetworkString("nzu_logic_setting")

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
			writefullunit(self)
		net.Broadcast()
	end

	-- Spawns the unit by networking its creation, finalizing its existence
	logic_metatable.Spawn = function(self)
		if self.m_bNetwork then self:NetworkCreation() end
		hook.Run("nzu_LogicUnitCreated", self)
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
		if not self.m_bNetwork then return end

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
		if not self.m_bNetwork then return end

		net.Start("nzu_logic_entitytie")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteBool(false)
		net.Broadcast()
	end

	-- Destroy the logic unit, including all output and input connections
	--[[logic_metatable.Remove = function(self)
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
	end]]
	logic_metatable.Remove = function(self)
		hook.Run("nzu_LogicUnitRemoved", self)

		local index = self.m_iIndex
		for k,v in pairs(self) do
			self[k] = nil
		end
		self.m_bDestroyed = true

		createdlogics[index] = nil

		net.Start("nzu_logic_creation")
			net.WriteUInt(index, 16)
			net.WriteBool(false)
		net.Broadcast()
	end

	-- Creates a connection between an output on this to an input on another unit
	-- Defines what arguments this connection carries
	-- Returns connection ID (used to remove)
	--[[logic_metatable.Connect = function(self, outp, target, inp, args)
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
	end]]

	logic_metatable.Connect = function(self, outp, target, inp, args, responsibleplayer)
		if target.Inputs[inp] then
			local c = self:GetOutputConnections()
			if not c[outp] then c[outp] = {} end

			local actualargs
			if args == "" then args = nil end
			if target.Inputs[inp].AcceptInput then
				local allowed, args2, parsed = target.Inputs[inp].AcceptInput(target, args)
				if not allowed then return end

				actualargs = args2
				args = parsed or args
			end

			local tbl = makeconnection(self, outp, target, inp, args)
			tbl.ActualArgs = actualargs
			local index = table.insert(c[outp], tbl)

			hook.Run("nzu_LogicUnitConnected", self, outp, index, tbl)
			if not self.m_bNetwork then return index end

			net.Start("nzu_logic_connection")
				net.WriteUInt(self.m_iIndex, 16)
				net.WriteUInt(index, 16)
				net.WriteBool(true)

				net.WriteString(outp)
				net.WriteUInt(target.m_iIndex, 16)
				net.WriteString(inp)

				
				net.WriteString(args or "")
			net.Broadcast()

			return index
		end
	end

	-- Sets the connection settings of a specified connection
	-- This is close to recreating, but more along the lines of overwriting
	logic_metatable.SetConnectionSettings = function(self, outp, connectionid, args)
		local c = self:GetOutputConnections()
		if not c[outp] or not c[outp][connectionid] then return end
		local connection = c[outp][connectionid]
		local target = connection.Target
		local inp = connection.Input

		local actualargs
		if args == "" then args = nil end
		if target.Inputs[inp].AcceptInput then
			local allowed, args2, parsed = target.Inputs[inp].AcceptInput(target, args)
			if not allowed then return end

			actualargs = args2
			args = parsed or args
		end

		connection.Args = args
		connection.ActualArgs = actualargs

		hook.Run("nzu_LogicUnitConnectionChanged", self, outp, connectionid, connection)
		if not self.m_bNetwork then return end

		net.Start("nzu_logic_connection_setting")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteUInt(connectionid, 16)
			net.WriteString(outp)
			net.WriteString(args or "")
		net.Broadcast()
	end

	-- Disconnects a connection from an ouput
	-- Requires specifying what output to disconnect from and what id
	logic_metatable.Disconnect = function(self, outp, connectionid)
		local c = self:GetOutputConnections()
		if not c[outp] or not c[outp][connectionid] then return end
		
		hook.Run("nzu_LogicUnitDisconnected", self, outp, connectionid, c[outp][connectionid])

		-- We can't table.remove as it shifts the indexes of other entries down, which breaks their connectionid
		c[outp][connectionid] = nil
		if not self.m_bNetwork then return end

		net.Start("nzu_logic_connection")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteUInt(connectionid, 16)
			net.WriteBool(false)

			net.WriteString(outp)
		net.Broadcast()
	end

	-- These are the types you can send
	-- Read types are just defined in net.ReadVars
	-- We had to not use net.WriteVars because they'd also send an unnecesasry 8 bit UInt
	local writetypes = {
		[TYPE_STRING]		= function ( t, v )	net.WriteString( v )		end,
		[TYPE_NUMBER]		= function ( t, v )	net.WriteDouble( v )		end,
		[TYPE_TABLE]		= function ( t, v )	net.WriteTable( v )			end,
		[TYPE_BOOL]			= function ( t, v )	net.WriteBool( v )			end,
		[TYPE_ENTITY]		= function ( t, v )	net.WriteEntity( v )		end,
		[TYPE_VECTOR]		= function ( t, v )	net.WriteVector( v )		end,
		[TYPE_ANGLE]		= function ( t, v )	net.WriteAngle( v )			end,
		[TYPE_MATRIX]		= function ( t, v )	net.WriteMatrix( v )		end,
		[TYPE_COLOR]		= function ( t, v )	net.WriteColor( v )			end,
	}

	-- Sets a setting on this Logic Unit. Networks using net.WriteType and net.ReadType. However a NetSend and NetRead
	-- function can be defined to save a little bandwidth or allow custom networking (such as a list of options)
	-- Does not work with tables unless NetSend and NetRead is implemented to handle it
	logic_metatable.SetSetting = function(self, setting, val)
		if not self.Settings[setting] then return end
		local settingtbl = self.Settings[setting]
		if settingtbl.Parse then val = settingtbl.Parse(self, val) end

		self.m_tSettings[setting] = val

		hook.Run("nzu_LogicUnitSettingChanged", self, setting, val)
		if not self.m_bNetwork then return end

		net.Start("nzu_logic_setting")
			net.WriteUInt(self.m_iIndex, 16)
			net.WriteString(setting)
			if settingtbl.NetSend then
				settingtbl.NetSend(self, val)
			elseif settingtbl.Type then
				writetypes[settingtbl.Type](val)
			end
		net.Broadcast()
	end

	-- Do a full sync to a player; this completely refreshes (or recreates) this unit and its properites
	-- for that player. Can pass a table of players or otherwise acceptable net.Send recipients
	logic_metatable.FullSync = function(self, ply)
		net.Start("nzu_logic_creation")
			writefullunit(self)
		net.Send(ply)

		for k,v in pairs(self:GetConnections()) do
			for k2,v2 in pairs(v) do
				net.Start("nzu_logic_connection")
					net.WriteUInt(self.m_iIndex, 16)
					net.WriteUInt(k2, 16)
					net.WriteBool(true)

					net.WriteString(k)
					net.WriteUInt(v2.Target.m_iIndex, 16)
					net.WriteString(v2.Input)
					net.WriteString(v2.Args or "")
				net.Send(ply)
			end
		end

		for k,v in pairs(self.Settings) do
			net.Start("nzu_logic_setting")
				net.WriteUInt(self.m_iIndex, 16)
				net.WriteString(k)
				if v.NetSend then
					v.NetSend(self, self.m_tSettings[k])
				elseif v.Type then
					writetypes[v.Type](self.m_tSettings[k])
				end
			net.Send(ply)
		end
	end

else
	-- Receive networking around creation of logic units
	net.Receive("nzu_logic_creation", function()
		local index = net.ReadUInt(16)
		if net.ReadBool() then
			local class = net.ReadString()
			local pos = net.ReadVector()
			local entity = net.ReadBool() and net.ReadEntity() or nil

			local unit = class and makelogic(class)
			if unit then
				createdlogics[index] = unit
				unit.m_iIndex = index
				unit.m_vPos = pos or Vector()
				if entity then unit.m_eTiedEntity = entity end

				hook.Run("nzu_LogicUnitCreated", unit)
			end
		else
			if createdlogics[index] then
				hook.Run("nzu_LogicUnitRemoved", unit)
				for k,v in pairs(createdlogics[index]) do
					createdlogics[index][k] = nil
				end
				createdlogics[index].m_bDestroyed = true
			end
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
		if unit then
			unit:SetPos(pos)
			hook.Run("nzu_LogicUnitMoved", unit, pos)
		end
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

	-- Receive networking around connection and disconnection of logic units
	net.Receive("nzu_logic_connection", function()
		local unitindex = net.ReadUInt(16)
		local cid = net.ReadUInt(16)
		if createdlogics[unitindex] then
			local unit = createdlogics[unitindex]
			if net.ReadBool() then
				local outp = net.ReadString()
				local target = net.ReadUInt(16)
				local inp = net.ReadString()
				local args = net.ReadString()
				if args == "" then args = nil end
				
				if createdlogics[target] then
					local tbl = makeconnection(unit, outp, createdlogics[target], inp, args)
					local c = unit:GetOutputConnections()
					if not c[outp] then c[outp] = {} end

					c[outp][cid] = tbl
					hook.Run("nzu_LogicUnitConnected", unit, outp, cid, tbl)
				end
			else
				local c = unit:GetOutputConnections()
				local outp = net.ReadString()
				if c[outp] then
					hook.Run("nzu_LogicUnitDisconnected", unit, outp, cid, c[outp][cid])
					c[outp][cid] = nil
				end
			end
		end
	end)

	-- Receive networking around connection setting updates
	-- This should only update connections that already exist
	net.Receive("nzu_logic_connection_setting", function()
		local unitindex = net.ReadUInt(16)
		local cid = net.ReadUInt(16)
		local outp = net.ReadString()
		local args = net.ReadString()
		if IsValid(createdlogics[unitindex]) then
			local c = createdlogics[unitindex]:GetOutputConnections()
			if c and c[outp] and c[outp][cid] then
				c[outp][cid].Args = args ~= "" and args or nil
				hook.Run("nzu_LogicUnitConnectionChanged", unit, outp, cid, c[outp][cid])
			end
		end
	end)

	net.Receive("nzu_logic_setting", function()
		local index = net.ReadUInt(16)
		local unit = createdlogics[index]
		if unit then
			local setting = net.ReadString()
			local val
			if unit.Settings[setting] then
				local stbl = unit.Settings[setting]
				if stbl.NetRead then
					val = stbl.NetRead(unit)
				elseif stbl.Type then
					val = net.ReadVars[stbl.Type]()
				end
				unit.m_tSettings[setting] = val
				hook.Run("nzu_LogicUnitSettingChanged", unit, setting, val)
			end
		end
	end)
end
logic_metatable.__index = logic_metatable
logic_metatable.__tostring = function(self) return "nzu_Logic ["..self.m_iIndex.."]["..self.ClassName.."]" end
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

	-- Update all existing logic units with the refresh
	for k,v in pairs(createdlogics) do
		if v.ClassName == classname then
			table.Merge(v, LOGIC)
		end
	end

	return LOGIC
end

if SERVER then
	function nzu.CreateLogicUnit(class, nonetwork)
		local unit = makelogic(class)
		if unit then
			unit.m_iIndex = table.insert(createdlogics, unit)
			unit.m_bNetwork = not nonetwork

			-- We don't initialize it; it should only initialize when the actual game begins
			-- Likewise, Think doesn't run on it yet. The only thing that really works is positioning and settings

			return unit
		end
	end
end

function nzu.GetLogicUnit(id)
	return createdlogics[id]
end
function nzu.GetAllLogicUnits()
	local tbl = {}
	for k,v in pairs(createdlogics) do
		tbl[k] = v
	end
	return tbl
end

function nzu.GetStoredLogicUnit(class)
	return logicunits[class]
end
function nzu.GetLogicUnitList()
	local tbl = {}
	for k,v in pairs(logicunits) do
		tbl[k] = v
	end
	return tbl
end

-- Full sync (only available once per player per connect)
if SERVER then
	hook.Add("PlayerInitialSpawn", "nzu_Logic_Fullsync", function(ply)
		for k,v in pairs(createdlogics) do
			v:FullSync(ply)
		end
	end)
end