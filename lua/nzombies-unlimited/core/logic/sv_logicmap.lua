
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