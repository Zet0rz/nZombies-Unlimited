local ENTITY = FindMetaTable("Entity")

--function ENTITY:GetDoorData()
	--return self.nzu_DoorData
--end
ENTITY.GetDoorData = ENTITY.GetBuyFunction -- Since Door Data is just stored in the BuyFunction of the entity

if SERVER then
	local nzu = nzu

	local doorgroups = {}
	local nongroups = {}
	util.AddNetworkString("nzu_doors") -- Server: Broadcast door information to clients, individual doors
	util.AddNetworkString("nzu_doors_groups") -- Server: Broadcast door information to clients, group-optimized

	-- In nZombies, we only have to network the price and whether it requires electricity
	local function writedoordata(data)
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

		net.WriteBool(false)
		writedoordata(data)
	end

	-- Network groups at once
	local function networkdoorgroups(ply)
		if doorgroups then
			local groups = {}
			for k,v in pairs(doorgroups) do
				for k2,v2 in pairs(v) do
					local data = k2:GetDoorData()
					if data then
						if groups[data] then -- If this data is equal to an existing dataset. We know they're equal since direct referencing is done in ENTITY:CreateDoor()
							table.insert(groups[data], k2)
						else
							groups[data] = {k2}
						end
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

	-- Open doors when bought
	local function opendoorfunc(ply, ent)
		local data = ent:GetDoorData()
		if data then
			-- Since this is a BuyFunction, it is triggered on player using the entity
			-- We can return true to allow the entity to be used normally so doors can display its effects
			-- nzu.OpenDoor returns the result of the OpenDoor function on that entity
			-- nzu.OpenDoorGroup returns a table of results

			if data.Group then
				local results = nzu.OpenDoorGroup(data.Group, ply, ent)
				return results[ent]
			else
				return nzu.OpenDoor(ent, ply)
			end
		end
	end

	-- Simulate door being locked if attempted to be opened when you can't
	local doorclasses = {
		["func_door"] = true,
		["func_door_rotating"] = true,
		["prop_door_rotating"] = true,
	}
	local function failopendoor(ply, ent)
		ent:SetSaveValue("m_bLocked", true) -- Set to locked, then try to open. That'll play the door's locked effect
		--ent:Use(ply, ply, USE_ON, 1)
		return true -- Allow the normal use, but we're locked
	end

	function ENTITY:CreateDoor(data)
		-- Sanity check
		data.Price = data.Price or 0

		local networkclone
		if data.Group then
			local gtbl = doorgroups[data.Group]
			if not gtbl then
				gtbl = {}
				doorgroups[data.Group] = gtbl
			end

			if self.nzu_DoorHooked then
				gtbl[self] = true
				return -- No networking, no function! Just place into the table so that this entity will be opened as well
			end

			-- Optimization: If this door belongs to a group, loop through other doors in this group and see if any are the same dataset
			-- If so, just clone data from that in networking (and memory)
			for k,v in pairs(gtbl) do
				local data2 = k:GetDoorData()
				if data2 and data2.Price == data.Price and data2.Electricity == data.Electricity then
					if data2.Rooms == nil and data.Rooms == nil then
						data = data2 -- We found a clone!
						networkclone = k
					elseif data2.Rooms and data.Rooms then
						local clone = {}
						for k2,v2 in pairs(data.Rooms) do
							clone[v2] = true
						end

						local isclone = true
						for k2,v2 in pairs(data2.Rooms) do
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

			gtbl[self] = true
		else
			nongroups[self] = true
		end

		-- Apply stuff for the buy function
		data.Function = opendoorfunc
		if doorclasses[self:GetClass()] then
			data.FailFunction = failopendoor
			self:SetSaveValue("m_bLocked", true) -- For good measure
		end
		self:SetBuyFunction(data, true) -- Don't network it, we do it ourselves

		if not nonetwork then
			net.Start("nzu_doors")
				networkdoordata(self, data, networkclone)
			net.Broadcast()
		end

		if data.FlagOpen and data.Rooms then
			self:SetRoomHandler("DoorAutoOpen")
			self:SetRooms(data.Rooms)
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
	local effectdelay = 1
	local function openprops(ent, ply, t, initial)
		if not initial or ent == initial then
			sound.Play("nzu/doors/disappear.wav", ent:GetPos(), 75, 100, 1)
		end

		ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS) -- No longer collide
		local e = EffectData()
		e:SetEntity(ent)
		e:SetScale(effectdelay)
		e:SetMagnitude(0.5)
		e:SetRadius(0)
		util.Effect("nzu_debris_clear", e, true, true)

		SafeRemoveEntityDelayed(ent, effectdelay)
	end

	-- Functions for getting whether a door is open by its SaveTable
	local opentest = {
		["func_door"] = function(e) return e.m_toggle_state == 0 end,
		["func_door_rotating"] = function(e) return e.m_toggle_state == 0 end,
		["prop_door_rotating"] = function(e) return e.m_eDoorState ~= 0 end,
	}

	local function opendoors(ent, ply, t, initial)
		local svtbl = ent:GetSaveTable()
		local slave = svtbl.slavename

		-- Do nothing if the enslaved door group was already triggered this Door Group cycle!
		if t then
			if t[ent] ~= nil then return initial == ent end
		end

		local doors = {}
		if not opentest[ent:GetClass()](svtbl) then
			doors[ent] = svtbl.m_bLocked
		end

		-- If we're paired to other doors, get all of those too
		if slave and slave ~= "" then
			for k,v in pairs(ents.FindByName(slave)) do
				if not v:IsPlayer() and v ~= ent then
					local tbl = v:GetSaveTable()
					if not opentest[v:GetClass()](tbl) then
						doors[v] = tbl.m_bLocked -- Save the door as key and whether locked as value
					end
					t[v] = true -- Don't handle this in another cycle
				end
			end
		end

		-- Loop through all doors and unlock the locked ones
		for k,v in pairs(doors) do
			if v then k:SetSaveValue("m_bLocked", false) end
		end

		
		if IsValid(ply) then -- Use the targeted door to open it as if the player did
			if initial and ent ~= initial then ent:Use(ply, ply, USE_ON, 1) end

			timer.Simple(0, function()
				for k,v in pairs(doors) do
					if IsValid(k) then
						k:SetSaveValue("m_bLocked", true)
						k:SetSaveValue("returndelay", -1)
					end
				end
			end)

			return true
		else -- Open it as if no one did (any direction)
			local awayfrom = slave or ent:GetName()
			for k,v in pairs(doors) do
				k:Fire("OpenAwayFrom", "!player")
				k:SetSaveValue("returndelay", -1)
				timer.Simple(0.1, function() if IsValid(k) then k:SetSaveValue("m_bLocked", true) end end)
			end
		end
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
	function dooropeneffect(ent, ply, t, initial)
		if ent.OpenDoor then return ent:OpenDoor(ply, t, initial) end -- Call their own door effect

		local func = doortypes[ent:GetClass()]
		if func then return func(ent, ply, t, initial) else
			ent:Fire("Open") -- Just to ensure area portals/whatnot are opened with it
			ent:Remove()
		end
	end

	function nzu.OpenDoor(ent, ply, t, initial)
		if not IsValid(ent) then return end

		local data = ent:GetDoorData()
		ent:RemoveDoor()
		if data and data.Rooms then
			for k,v in pairs(data.Rooms) do
				nzu.OpenRoom(v)
			end
		end
		local b = dooropeneffect(ent, ply, t, initial)
		hook.Run("nzu_DoorOpened", ent, ply)
		return b
	end

	function nzu.OpenDoorGroup(id, ply, initial)
		local doors = doorgroups[id]
		if doors then
			local t = {}
			for k,v in pairs(doors) do
				t[k] = nzu.OpenDoor(k, ply, t, initial)
			end
			doorgroups[id] = nil
			hook.Run("nzu_DoorGroup_"..id, ply)
			hook.Run("nzu_DoorGroupOpened", id, ply)

			return t
		end
	end

	function nzu.BuyDoor(ent, ply)
		local data = ent:GetDoorData()
		if data then
			if IsValid(ply) then
				return ply:Buy(data.Price, function()
					if data.Group then
						nzu.OpenDoorGroup(data.Group, ply, ent)
					else
						nzu.OpenDoor(ent, ply)
					end
				end)
			else -- No player given. Open the door for free (server-authorized)
				if data.Group then
					nzu.OpenDoorGroup(data.Group, ply, ent)
				else
					nzu.OpenDoor(ent, ply)
				end
			end
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
					nzu.BuyDoor(k2)
				end
			end
		end
		for k,v in pairs(nongroups) do
			local data = k:GetDoorData()
			if data and data.Price == 0 and data.Electricity then
				nzu.BuyDoor(k)
			end
		end
	end)

	-- Also open doors with power overrides
	hook.Add("nzu_OnEntityElectricityOn", "nzu_Doors_OpenElectricityDoors", function(ent)
		local data = ent:GetDoorData()
		if data and (data.Group and doorgroups[data.Group][ent] or nongroups[ent]) then -- Verify it is a door in our system!
			if data.Price == 0 and data.Electricity then
				nzu.BuyDoor(ent)
			end
		end
	end)

	-- Hook for when the game starts, open all doors that are free and require no electricity
	hook.Add("nzu_GameStarted", "nzu_Doors_OpenAllFreeDoors", function()
		for k,v in pairs(doorgroups) do
			for k2,v2 in pairs(v) do
				local data = k2:GetDoorData()
				if data and data.Price == 0 and not data.Electricity then
					nzu.BuyDoor(k2)
				end
			end
		end
		for k,v in pairs(nongroups) do
			local data = k:GetDoorData()
			if data and data.Price == 0 and not data.Electricity then
				nzu.BuyDoor(k)
			end
		end
	end)

	--[[-------------------------------------------------------------------------
	Auto-opening doors if all connected rooms are opened
	---------------------------------------------------------------------------]]
	nzu.AddRoomHandler("DoorAutoOpen", function(door, room)
		local data = door:GetDoorData()
		if not data then return end

		for k,v in pairs(door.nzu_Rooms) do
			if not nzu.IsRoomOpen(k) then return true end -- Don't remove the handler/rooms from us yet
		end

		if data.Group then
			nzu.OpenDoorGroup(data.Group, nil, nil, door)
		else
			nzu.OpenDoor(door, nil, nil, door)
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
			local tbl
			if net.ReadBool() then
				local ent2 = net.ReadUInt(16)
				if IsValid(Entity(ent2)) then tbl = Entity(ent2):GetBuyFunction() else tbl = queue[ent2] end
			else
				tbl = {}
				tbl.Price = net.ReadUInt(32)
				if net.ReadBool() then
					tbl.Electricity = true
				end

				tbl.TargetIDType = TARGETID_TYPE_USECOST
				tbl.Text = " clear debris "
			end

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