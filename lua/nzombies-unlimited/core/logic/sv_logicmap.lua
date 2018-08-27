
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
		unit:LogicConnect(outport, unit2, inport, args, ply)
	end
end)

util.AddNetworkString("nzu_logicmap_setting")
net.Receive("nzu_logicmap_setting", function(len, ply)
	local index = net.ReadUInt(16)

	local unit = nzu.GetLogicUnit(index)
	if IsValid(unit) then
		local setting, val = unit:NetReadLogicSetting()
		if setting and val then 
			unit:SetLogicSetting(setting, val)
		end
	end
end)