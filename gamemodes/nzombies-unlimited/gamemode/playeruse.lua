local PLAYER = FindMetaTable("Player")
local ENTITY = FindMetaTable("Entity")

--[[-------------------------------------------------------------------------
Applying Buy functions - Run when the player attempts to use the entity
---------------------------------------------------------------------------]]

local nw_price = "nzu_UseCost"
local nw_text = "nzu_UseText"
local nw_elec = "nzu_UseElec"

--[[
	Structure of a Buy Function:
	- Price: The price. Can be 0 to be free, or negative to give points
	- Electricity: True if it requires electricity
	- Function: What to run when bought
	- Rebuy: True if the function should stay - False and the function disappears after use
]]

--[[if SERVER then
	util.AddNetworkString("nzu_buyfunctions")

	function ENTITY:SetBuyFunction(data, nonetwork)
		self.nzu_BuyFunction = data
		data.NoNetwork = nonetwork

		if not nonetwork then
			self:SetNW2Int(nw_price, price)
			self:SetNW2Bool(nw_elec, elec)
			self:SetNW2String(nw_text, buytext)
			self.nzu_UseCostRebuy = rebuy
		end
	end

	function ENTITY:RemoveBuyFunction()
		if self.nzu_BuyFunction then
			self.nzu_BuyFunction = nil
		end
	end
else
	-- Draw text for clients
	hook.Add("nzu_GetTargetIDText", "nzu_Doors_TargetID", function(ent)
		local price = ent:GetNW2Int(nw_price, nil)
		if price then
			local elec = ent:GetNW2Bool(nw_elec, false)
			if not elec then
				local str = ent:GetNW2String(nw_text, "")
				if price ~= 0 then
					return str, TARGETID_TYPE_USECOST, price
				else
					return str, TARGETID_TYPE_USE
				end
			else
				return "Requires Electricity", TARGETID_TYPE_ELECTRICITY
			end
		end
	end)
end]]


--[[-------------------------------------------------------------------------
Player Use handling
---------------------------------------------------------------------------]]
if SERVER then
	local usecooldown = 0.1

	-- We prevent using here. Another hook can easily block this though, but we do this to optimize saving a trace
	hook.Add("FindUseEntity", "nzu_PlayerUse_PreventDownedUse", function(ply, ent)
		if ply:GetIsDowned() then return NULL end
	end)

	-- Call new hooks when the player starts/stops using, or switches use target
	function GM:PlayerUse(ply, ent)
		if ply:GetIsDowned() then
			if ply.nzu_UseTarget then
				local ent2 = ply.nzu_UseTarget
				hook.Run("nzu_PlayerStopUse", ply, ent2)
				ply.nzu_UseTarget = nil
				ply.nzu_UseCooldown = CurTime() + usecooldown
			end
			return false -- Even if another hook should return another entity, prevent use
		end
		if ply.nzu_UseCooldown and ply.nzu_UseCooldown > CurTime() then return false end

		local ent2 = ply.nzu_UseTarget
		if ent2 ~= ent then
			ply.nzu_UseTarget = ent

			if IsValid(ent2) then
				hook.Run("nzu_PlayerStopUse", ply, ent2)
			end

			if IsValid(ent) then
				hook.Run("nzu_PlayerStartUse", ply, ent)
			end
		else
			hook.Run("nzu_PlayerUse", ply, ent)
		end
		return true
	end

	-- Also stop for E
	hook.Add("KeyRelease", "nzu_PlayerUse_StopHoldingE", function(ply, key)
		if key == IN_USE and IsValid(ply.nzu_UseTarget) then
			local ent = ply.nzu_UseTarget
			ply.nzu_UseTarget = nil
			ply.nzu_UseCooldown = CurTime() + usecooldown
			hook.Run("nzu_PlayerStopUse", ply, ent)
		end
	end)
end

--[[-------------------------------------------------------------------------
Player Buy shortcut function
---------------------------------------------------------------------------]]
function PLAYER:Buy(cost, func)
	if self:CanAfford(cost) then
		self:TakePoints(cost)
		return true, func(self)
	end
	return false
end