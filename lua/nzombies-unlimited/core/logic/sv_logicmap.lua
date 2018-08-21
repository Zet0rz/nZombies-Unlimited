
print("hi")

util.AddNetworkString("nzu_logicmap_create")
net.Receive("nzu_logicmap_create", function(len, ply)
	local class = net.ReadString()
	local pos = net.ReadVector()

	local unit = nzu.CreateLogicUnit(class)
	if IsValid(unit) then
		unit:SetPos(pos)
		unit:Spawn()
	end
end)

util.AddNetworkString("nzu_logicmap_move")
net.Receive("nzu_logicmap_move", function(len, ply)
	local index = net.ReadUInt(16)
	local pos = net.ReadVector()

	local unit = nzu.GetLogicUnit(index)
	if IsValid(unit) then
		unit:SetPos(pos)
	end
end)

util.AddNetworkString("nzu_logicmap_connect")
net.Receive("nzu_logicmap_connect", function(len, ply)
	local index = net.ReadUInt(16)
	local outport = net.ReadString()
	local target = net.ReadUInt(16)
	local inport = net.ReadString()
	local args = net.ReadString()

	local unit = nzu.GetLogicUnit(index)
	local unit2 = nzu.GetLogicUnit(target)
	if IsValid(unit) and IsValid(unit2) then
		unit:Connect(outport, unit2, inport, args, ply)
	end
end)

util.AddNetworkString("nzu_logicmap_setting")
net.Receive("nzu_logicmap_setting", function(len, ply)
	local index = net.ReadUInt(16)
	local setting = net.ReadString()

	local unit = nzu.GetLogicUnit(index)
	if IsValid(unit) and unit.Settings[setting] then
		local val
		local stbl = unit.Settings[setting]
		if stbl.NetRead then
			val = stbl.NetRead(unit)
		elseif stbl.Type then
			val = net.ReadVars[stbl.Type]()
		end
		unit:SetSetting(setting, val)
	end
end)