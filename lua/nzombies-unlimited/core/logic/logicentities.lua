
if SERVER then
	util.AddNetworkString("nzu_logicmap_position")
	util.AddNetworkString("nzu_logicmap_connection")
else
	
end

local logic_point = {}
function NZ:RegisterPointLogic(class, data)
	logic_point[class] = data
end
function NZ:GetPointLogic()
	return logic_point
end

hook.Add("InitPostEntity", "nZU_RegisterLogic", function()
	for k,v in pairs(scripted_ents.GetList()) do
		if v.NZU_LOGIC and v.Type == "point" then
			NZ:RegisterPointLogic(k, v.NZU_LOGIC)
		end
	end
end)