
local function clearragdoll(rag, time)
	timer.Simple(time, function()
		if IsValid(rag) then
			rag:SetSaveValue("m_bFadingOut", true)
		end
	end)
end

if not ConVarExists("nzu_ragdolls_maxtime_client") then CreateConVar("nzu_ragdolls_maxtime_client", 30, {FCVAR_ARCHIVE}, "How long CLIENT ragdolls stay before they are removed in nZombies Unlimited.") end

function GM:CreateClientsideRagdoll(ent, rag)
	clearragdoll(rag, GetConVarNumber("nzu_ragdolls_maxtime_client"))
end