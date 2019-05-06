
local iselec = false
function nzu.Electricity() return iselec end

--[[-------------------------------------------------------------------------
Entity override's and per-entity
---------------------------------------------------------------------------]]
local nw_elec = "nzu_Electricity"
local ENTITY = FindMetaTable("Entity")

-- You should use this function instead of nzu.Electricity()
-- It allows each entity to be individually powered
function ENTITY:HasElectricity()
	return self:GetNW2Bool(nw_elec, nzu.Electricity())
end

-- Turn on an entity. Set nil to return to global state (false will power it down)
-- This should normally only be done on SERVER
function ENTITY:SetElectricity(b)
	self:SetNW2Bool(nw_elec, b)
end

-- Power them when changed!
hook.Add("EntityNetworkedVarChanged", "nzu_Electricity_OverrideChanged", function(ent, key, old, new)
	if key == nw_elec and new ~= ent:HasElectricity() then
		if new then
			if ent.OnElectricityOn then ent:OnElectricityOn() end
			hook.Run("nzu_OnEntityElectricityOn", ent)
		else
			if ent.OnElectricityOff then ent:OnElectricityOff() end
			hook.Run("nzu_OnEntityElectricityOff", ent)
		end
	end
end)

--[[-------------------------------------------------------------------------
Global state
---------------------------------------------------------------------------]]

-- Loop through all entities and call the appropriate function for all that has it
-- But only if they don't already have this state of power
local function toggleelec()
	local func = iselec and "OnElectricityOn" or "OnElectricityOff"
	for k,v in pairs(ents.GetAll()) do
		if v[func] and v:GetNW2Bool(nw_elec, 1) == 1 then -- If it has the function, and it has no override
			v[func]()
		end
	end
end

if SERVER then
	util.AddNetworkString("nzu_electricity") -- Server: Broadcast electricity state
	function nzu.TurnOnElectricity()
		iselec = true
		net.Start("nzu_electricity")
			net.WriteBool(true)
		net.Broadcast()

		toggleelec()
		hook.Run("nzu_OnElectricityOn")
	end
	
	function nzu.TurnOffElectricity()
		iselec = false
		net.Start("nzu_electricity")
			net.WriteBool(false)
		net.Broadcast()

		toggleelec()
		hook.Run("nzu_OnElectricityOff")
	end

	-- Do electricity permanent if the map has no power switch	
	hook.Add("nzu_GameStarted", "nzu_Electricity_Start", function()
		if hook.Run("nzu_ShouldElectricityStartOff") then
			nzu.TurnOffElectricity()
		else
			nzu.TurnOnElectricity()
		end
	end)
else
	net.Receive("nzu_electricity", function()
		iselec = net.ReadBool()
		toggleelec()
		hook.Run(iselec and "nzu_OnElectricityTurnedOn" or "nzu_OnElectricityTurnedOff")
	end)

	-- Global sounds!
	local onsound = Sound("nzu/power/power_up.wav")
	local offsound = Sound("nzu/power/power_down.wav")
	hook.Add("nzu_OnElectricityTurnedOn", "nzu_Electricity_GlobalSound", function() surface.PlaySound(onsound) end)
	hook.Add("nzu_OnElectricityTurnedOff", "nzu_Electricity_GlobalSound", function() surface.PlaySound(offsound) end)
end