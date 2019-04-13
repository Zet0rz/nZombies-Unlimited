local PLAYER = FindMetaTable("Player")
local ENTITY = FindMetaTable("Entity")

--[[-------------------------------------------------------------------------
Applying Buy functions - Run when the player attempts to use the entity
---------------------------------------------------------------------------]]

--local nw_price = "nzu_UseCost"
--local nw_text = "nzu_UseText"
--local nw_elec = "nzu_UseElec"

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

function ENTITY:GetBuyFunction()
	return self.nzu_BuyFunction
end

if SERVER then
	util.AddNetworkString("nzu_buyfunctions") -- Server: Broadcast an entity's buy function

	local networkedents = {}
	local function writebuyfunc(ent, data)
		net.WriteEntity(ent)
		net.WriteBool(true)
		net.WriteUInt(data.Price, 32)
		net.WriteBool(data.Electricity)
		net.WriteBool(data.Rebuyable)
		net.WriteUInt(data.TargetIDType or TARGETID_TYPE_USECOST, 4)
		net.WriteString(data.Text or "")
	end
	function ENTITY:SetBuyFunction(data, nonetwork)
		self.nzu_BuyFunction = data
		if not nonetwork then
			if data then -- Send data
				net.Start("nzu_buyfunctions")
					writebuyfunc(ent, data)
				net.Broadcast()
				networkedents[self] = true

			elseif networkedents[self] then -- Send removal only if previously networked
				net.Start("nzu_buyfunctions")
					net.WriteEntity(self)
					net.WriteBool(false)
				net.Broadcast()
				networkedents[self] = nil
			end
		else
			networkedents[self] = nil
		end
	end

	hook.Add("PlayerInitialSpawn", "nzu_PlayerUse_BuyFunctionSync", function(ply)
		for k,v in pairs(networkedents) do
			net.Start("nzu_buyfunctions")
				writebuyfunc(k, k.nzu_BuyFunction)
			net.Send(ply)
		end
	end)

	-- Allow blocking the entity
	function ENTITY:BlockUse(b)
		if b then self.nzu_UseBlocked = true else self.nzu_UseBlocked = nil end
	end
else
	-- Clientside mirror, allows for shared creation (such as in Initialize) to save networking
	-- Or you can call this in your own client receiving if you can optimize networking (Door system does this)
	function ENTITY:SetBuyFunction(data)
		self.nzu_BuyFunction = data
	end

	local queue = {}
	local function applybuyfunc(index, data)
		local ent = Entity(index)
		if IsValid(ent) then
			ent.nzu_BuyFunction = data
		else
			queue[index] = data
		end
	end
	hook.Add("OnEntityCreated", "nzu_PlayerUse_BuyFunctionQueue", function(ent)
		if queue[ent:EntIndex()] then
			ent.nzu_BuyFunction = queue[ent:EntIndex()]
			queue[ent:EntIndex()] = nil
		end
	end)

	net.Receive("nzu_buyfunctions", function()
		local ent = net.ReadUInt(16)
		if net.ReadBool() then
			local tbl = {}
			tbl.Price = net.ReadUInt(32)

			if net.ReadBool() then
				tbl.Electricity = true
			end

			if net.ReadBool() then
				tbl.Rebuyable = true
			end


			tbl.TargetIDType = net.ReadUInt(4)
			tbl.Text = net.ReadString()

			if tbl.TargetIDType == 0 then
				tbl.TargetIDType = nil
				tbl.Text = nil
			end

			applybuyfunc(ent, tbl)
			hook.Run("nzu_BuyFunctionSet", ent, tbl)
		else
			applybuyfunc(ent, nil)
			hook.Run("nzu_BuyFunctionRemoved", ent)
		end
	end)

	-- Draw text for the buy function
	hook.Add("nzu_GetTargetIDText", "nzu_PlayerUse_TargetID", function(ent)
		local data = ent:GetBuyFunction()
		if data and data.TargetIDType then
			if data.Electricity and not ent:HasElectricity() then
				return "Requires Electricity", TARGETID_TYPE_ELECTRICITY
			end
			
			return data.Text, data.TargetIDType, data.Price
		end
	end)
end


--[[-------------------------------------------------------------------------
Player Use handling
---------------------------------------------------------------------------]]
if SERVER then
	function ENTITY:UseCooldown(num)
		self.nzu_UseCooldown = CurTime() + num
	end

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
		if ent.nzu_UseBlocked then return false end

		local ent2 = ply.nzu_UseTarget
		if ent2 ~= ent then
			ply.nzu_UseTarget = ent

			if IsValid(ent2) then
				hook.Run("nzu_PlayerStopUse", ply, ent2)
			end

			if IsValid(ent) and (not ent.nzu_UseCooldown or ent.nzu_UseCooldown < CurTime()) then
				hook.Run("nzu_PlayerStartUse", ply, ent)

				-- Buy functions!
				local data = ent:GetBuyFunction()
				if data then

					-- Can't use entities that require electricity it doesn't have!
					-- Allow use however if the FailFunction exists and returns true
					if data.Electricity and not ent:HasElectricity() then return data.FailFunction and data.FailFunction(ply, ent) or false end

					-- Free buy functions don't go through Buy - We don't want sounds
					if data.Price == 0 then
						local b = data.Function(ply, ent) -- Get the return of the function that would've been bought
						if b ~= false then -- If it didn't return false, it succeeded
							if not data.Rebuyable then ent:SetBuyFunction(nil) end

							-- Return only if the function explicitly returned something. Otherwise false (blocks use)
							return b ~= nil and b
						end

						-- Otherwise allowing use only if the FailFunction exists and returns true
						return data.FailFunction and data.FailFunction(ply, ent) or false
					else

						-- It has a cost, so we want to buy!
						local success,ret = ply:Buy(data.Price, data.Function, ent)
						if success then -- If the purchase was successful
							if not data.Rebuyable then ent:SetBuyFunction(nil) end  -- Remove buy function from non-rebuyables

							-- Return only if the result is not explicitly nil
							return ret ~= nil and ret
						end

						-- Otherwise, same as before: Let fail function determine outcome
						return data.FailFunction and data.FailFunction(ply, ent) or false
					end
				end
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
local buysound = Sound("nzu/purchase/accept.wav")
local denysound = Sound("nzu/purchase/deny.wav")
function PLAYER:Buy(cost, func, args)
	if self:CanAfford(cost) then
		local b = func and func(self, args) -- If the function returns false, it blocked the purchase
		if b ~= false then
			self:TakePoints(cost)
			self:EmitSound(buysound)
			return true, b
		end
	end
	self:EmitSound(denysound)
	return false
end