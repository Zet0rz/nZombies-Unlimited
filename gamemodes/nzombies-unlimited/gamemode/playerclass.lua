local datatables = {}
function nzu.AddPlayerNetworkVar(type, name, extended)
	if not datatables[type] then datatables[type] = {} end
	local slot = table.insert(datatables[type], {name, extended})

	-- Install into all current players
	if SERVER then
		for k,v in pairs(player.GetAll()) do
			if v.nzu_dt then
				v:NetworkVar(type, slot, name, extended)
			end
		end
	elseif LocalPlayer().nzu_dt then
		LocalPlayer():NetworkVar(type, slot, name, extended)
	end
end

local notifies = {}
function nzu.AddPlayerNetworkVarNotify(name, func) -- Doesn't really work on client right now :/
	if not notifies[name] then notifies[name] = {} end
	table.insert(notifies[name], func)

	-- Install into all current players
	if SERVER then
		for k,v in pairs(player.GetAll()) do
			if v.nzu_dt then
				v:NetworkVarNotify(name, func)
			end
		end
	elseif LocalPlayer().nzu_dt then
		LocalPlayer():NetworkVarNotify(name, func)
	end
end

function nzu.InstallPlayerNetworkVars(ply)
	ply:InstallDataTable()

	for k,v in pairs(datatables) do
		for slot,data in pairs(v) do
			ply:NetworkVar(k, slot, data[1], data[2])
		end
	end

	for k,v in pairs(notifies) do
		for k2,v2 in pairs(v) do
			ply:NetworkVarNotify(k, v2)
		end
	end

	-- This will get overwritten if something else does ply:InstallDataTable() as the "dt" will be a new empty table
	-- We use this to check whether our default non-class network vars exist, or not
	ply.nzu_dt = true
end

hook.Add("OnEntityCreated", "nzu_PlayerNetworkVars", function(ply)
	if ply:IsPlayer() then
		nzu.InstallPlayerNetworkVars(ply)
	end
end)