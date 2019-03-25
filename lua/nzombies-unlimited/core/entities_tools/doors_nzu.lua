local ENTITY = FindMetaTable("Entity")

--function ENTITY:GetDoorData()
	--return self.nzu_DoorData
--end
ENTITY.GetDoorData = ENTITY.GetBuyFunction -- Since Door Data is just stored in the BuyFunction of the entity

if SERVER then
	local nzu = nzu

	local doorgroups
	local nongroups
	util.AddNetworkString("nzu_doors") -- Server: Broadcast door information to clients, individual doors
	util.AddNetworkString("nzu_doors_groups") -- Server: Broadcast door information to clients, group-optimized

	-- In nZombies, we only have to network the price and whether it requires electricity
	local function writedoordata(data)
		PrintTable(data)
		net.WriteUInt(data.Price, 32)
		net.WriteBool(data.Electricity)
	end

	local function networkdoordata(ent, data, clone)
		net.WriteEntity(ent)
		net.WriteBool(true)

		-- If clone exists, we can just tell clients to copy that!
		if IsValid(clone) then
			net.WriteBool(true)
			net.WriteEntity(clone)
			return
		end

		writedoordata(data)
	end

	-- Network groups at once
	local function networkdoorgroups(ply)
		if doorgroups then
			local groups = {}
			for k,v in pairs(doorgroups) do
				local data = k:GetDoorData()
				if data then
					if groups[data] then -- If this data is equal to an existing dataset. We know they're equal since direct referencing is done in ENTITY:CreateDoor()
						table.insert(groups[data], k)
					else
						groups[data] = {k}
					end
				end
			end

			-- Now network number of groups and let's send them in bulk!
			-- We write the data for the doors only once, then we write all entities with this data!
			for k,v in pairs(groups) do
				net.Start("nzu_doors_groups")
					writedoordata(k)
					local numents = #v
					net.WriteUInt(numents, 32)
					for k2,v2 in pairs(v) do
						net.WriteEntity(v2)
					end
				if IsValid(ply) then net.Send(ply) else net.Broadcast() end
			end
		end

		-- We still gotta network the non-grouped ones separately, since without groups they shouldn't be grouped
		if nongroups then
			for k,v in pairs(nongroups) do
				net.Start("nzu_doors")
					networkdoordata(k, k:GetDoorData())
				if IsValid(ply) then net.Send(ply) else net.Broadcast() end
			end
		end
	end

	-- Loading in a network-efficient way
	local nonetwork = nil
	nzu.AddSaveExtension("Doors", {
		Load = function(doordata, doorents)
			doorgroups = {}
			nongroups = {}

			nonetwork = true
			for k,v in pairs(doordata) do
				local ent = doorents[k]
				if IsValid(ent) then
					ent:CreateDoor(v)
				end
			end
			hook.Run("nzu_PostLoadDoors") -- You can group additional doors in here to get it bulk-networked
			networkdoorgroups() -- This is optimized to bulk-networking

			nonetwork = nil
		end
	})

	local function opendoorfunc(ply, ent)
		local data = ent:GetDoorData()
		if data then
			if data.Group then
				nzu.OpenDoorGroup(data.Group, ply)
			else
				nzu.OpenDoor(ent, ply)
			end
		end
	end

	function ENTITY:CreateDoor(data)
		-- Sanity check
		data.Price = data.Price or 0

		local networkclone
		if data.Group then
			if not doorgroups[data.Group] then
				doorgroups[data.Group] = {}
			else
				-- Optimization: If this door belongs to a group, loop through other doors in this group and see if any are the same dataset
				-- If so, just clone data from that in networking (and memory)
				for k,v in pairs(doorgroups[data.Group]) do
					local data2 = k:GetDoorData()
					if data2.Price == data.Price and data2.Electricity == data.Electricity then
						if data2.Flags == nil and data.Flags == nil then
							data = data2 -- We found a clone!
							networkclone = k
						elseif data2.Flags and data.Flags then
							local clone = {}
							for k2,v2 in pairs(data.Flags) do
								clone[v2] = true
							end

							local isclone = true
							for k2,v2 in pairs(data2.Flags) do
								if clone[v2] then
									clone[v2] = nil
								else
									isclone = false
									break
								end
							end

							-- All keys match, and there's no remaining in the clone table!
							if isclone and not next(clone) then
								data = data2
								networkclone = k
							end
						end	
					end
				end
			end
			doorgroups[data.Group][self] = true
		else
			nongroups[self] = true
		end

		-- Apply stuff for the buy function
		data.Function = opendoorfunc
		self:SetBuyFunction(data, true) -- Don't network it, we do it ourselves

		if not nonetwork then
			net.Start("nzu_doors")
				networkdoordata(self, data, networkclone)
			net.Broadcast()
		end

		hook.Run("nzu_DoorLockCreated", self, data)
	end

	function ENTITY:RemoveDoor()
		local group = self.nzu_BuyFunction and self.nzu_BuyFunction.Group
		if group then
			doorgroups[self] = nil
		else
			nongroups[self] = nil
		end

		self:SetBuyFunction(nil, true)
		if not nonetwork then
			net.Start("nzu_doors")
				net.WriteEntity(self)
				net.WriteBool(false)
			net.Broadcast()
		end

		hook.Run("nzu_DoorLockRemoved", self)
	end

	-- Network to players that join
	hook.Add("PlayerInitialSpawn", "nzu_Doors_FullSync", function(ply)
		networkdoorgroups(ply)
	end)

	--[[-------------------------------------------------------------------------
	Opening doors
	---------------------------------------------------------------------------]]
	local effectdelay = 2
	local function openprops(ent)
		local e = EffectData()
		e:SetEntity(ent)
		e:SetScale(effectdelay)
		util.Effect("nzu_Effect_ClearDebris", e, nil, true)
		SafeRemoveEntityDelayed(ent, effectdelay)
	end

	-- Change this later to Open -> Lock, but support double doors
	local function opendoors(ent)
		ent:Remove()
	end

	local doortypes = {
		["func_door"] = opendoors,
		["func_door_rotating"] = opendoors,
		["prop_door_rotating"] = opendoors,
		["prop_dynamic"] = openprops,
		["prop_physics"] = openprops,
		["prop_physics_multiplayer"] = openprops,
		["prop_physics_override"] = openprops,
		["prop_dynamic_override"] = openprops,
	}
	local function dooropeneffect(ent)
		if ent.OpenDoor then ent:OpenDoor() return end -- Call their own door effect

		local func = doortypes[ent:GetClass()]
		if func then func(ent) else ent:Remove() end
	end

	function nzu.OpenDoor(ent, ply)
		local data = ent:GetDoorData()
		if data and data.Flags then
			for k,v in pairs(data.Flags) do
				nzu.OpenMapFlag(v)
			end
		end
		dooropeneffect(ent)
		hook.Run("nzu_DoorOpened", ent, ply)
	end

	function nzu.OpenDoorGroup(id, ply)
		local doors = doorgroups[id]
		if doors then
			for k,v in pairs(doors) do
				nzu.OpenDoor(k, ply)
			end
			doorgroups[id] = nil
			hook.Run("nzu_DoorGroupOpened", id, ply)
		end
	end

	function nzu.BuyDoor(ent, ply)
		local data = ent:GetDoorData()
		if data then
			return ply:Buy(data.Price, function()
				if data.Group then
					nzu.OpenDoorGroup(data.Group, ply)
				else
					nzu.OpenDoor(ent, ply)
				end
			end)
		end
	end

	function nzu.IsDoorGroupOpen(id)
		return not doorgroups[id]
	end

	-- Hook for when electricity is on, open all doors with 0 cost and electricity requirement
	hook.Add("nzu_OnElectricityOn", "nzu_Doors_OpenElectricityDoors", function()
		for k,v in pairs(doorgroups) do
			for k2,v2 in pairs(v) do
				local data = k2:GetDoorData()
				if data and data.Price == 0 and data.Electricity then
					nzu.OpenDoor(k2)
				end
			end
		end
		for k,v in pairs(nongroups) do
			local data = k:GetDoorData()
			if data and data.Price == 0 and data.Electricity then
				nzu.OpenDoor(k)
			end
		end
	end)

	-- Also open doors with power overrides
	hook.Add("nzu_OnEntityElectricityOn", "nzu_Doors_OpenElectricityDoors", function(ent)
		local data = ent:GetDoorData()
		if data and (data.Group and doorgroups[data.Group][ent] or nongroups[ent]) then -- Verify it is a door in our system!
			if data.Price == 0 and data.Electricity then
				nzu.OpenDoor(ent)
			end
		end
	end)
end

if CLIENT then
	local queue = {}
	local function doapplydoordata(index, data)
		local ent = Entity(index)
		if IsValid(ent) then
			ent:SetBuyFunction(data)
		else
			queue[index] = data
		end
	end
	hook.Add("OnEntityCreated", "nzu_Doors_DoorDataQueue", function(ent)
		if queue[ent:EntIndex()] then
			ent:SetBuyFunction(queue[ent:EntIndex()])
			queue[ent:EntIndex()] = nil
		end
	end)

	net.Receive("nzu_doors", function()
		local ent = net.ReadUInt(16)
		if net.ReadBool() then
			local tbl = {}
			tbl.Price = net.ReadUInt(32)
			if net.ReadBool() then
				tbl.Electricity = true
			end

			tbl.TargetIDType = TARGETID_TYPE_USECOST
			tbl.Text = " clear debris "

			doapplydoordata(ent, tbl)
			hook.Run("nzu_DoorLockCreated", ent, tbl)
		else
			doapplydoordata(ent, nil)
			hook.Run("nzu_DoorLockRemoved", ent)
		end
	end)

	net.Receive("nzu_doors_groups", function()
		local tbl = {}
		tbl.Price = net.ReadUInt(32)
		if net.ReadBool() then
			tbl.Electricity = true
		end

		tbl.TargetIDType = TARGETID_TYPE_USECOST
		tbl.Text = " clear debris "

		local num = net.ReadUInt(32)
		for i = 1, num do
			local ent = net.ReadUInt(16)
			doapplydoordata(ent, tbl)
			hook.Run("nzu_DoorLockCreated", ent, tbl)
		end
	end)
end