local ENTITY = FindMetaTable("Entity")

local doorpossibles = {
	["func_door"] = true,
	["func_door_rotating"] = true,
	["prop_door_rotating"] = true,
	["prop_dynamic"] = true,
	["prop_physics"] = true,
	["prop_physics_multiplayer"] = true,
	["prop_physics_override"] = true,
	["prop_dynamic_override"] = true,
}
function ENTITY:CanCreateDoor()
	return self.nzu_CanDoor or doorpossibles[self:GetClass()]
end

function ENTITY:GetDoorData()
	return self.nzu_DoorData
end


--[[-------------------------------------------------------------------------
Creation & Networking
---------------------------------------------------------------------------]]
if SERVER then
	util.AddNetworkString("nzu_doors") -- Server: Broadcast door information to clients
	local doors = {}

	local function networkdoordata(ent, data)
		net.WriteEntity(ent)
		net.WriteBool(true)
		net.WriteUInt(data.Price, 32)
		net.WriteBool(data.Electricity)
		net.WriteBool(data.FlagOpen)
		if data.Group then
			net.WriteBool(true)
			net.WriteString(data.Group)
		else
			net.WriteBool(false)
		end

		if data.Rooms then
			local num = #data.Rooms
			net.WriteUInt(num, 8)
			for k,v in pairs(data.Rooms) do
				net.WriteString(v)
			end
		end
	end
	function ENTITY:CreateDoor(data)
		if self.nzu_DoorHooked and not data.Group then return end

		-- Sanity check
		data.Price = data.Price or 0
		if data.Group == "" then data.Group = nil end

		self.nzu_DoorData = data
		net.Start("nzu_doors")
			networkdoordata(self, data)
		net.Broadcast()
		doors[self] = true

		hook.Run("nzu_DoorLockCreated", self, data)
	end

	function ENTITY:RemoveDoor()
		self.nzu_DoorData = nil
		net.Start("nzu_doors")
			net.WriteEntity(self)
			net.WriteBool(false)
		net.Broadcast()

		doors[self] = nil
		hook.Run("nzu_DoorLockRemoved", self)
	end
	nzu.IgnoreSaveField("nzu_DoorData") -- Make this field not save; We handle our own save data

	hook.Add("PlayerInitialSpawn", "nzu_Doors_InitSync", function(ply)
		for k,v in pairs(doors) do
			net.Start("nzu_doors")
				networkdoordata(k, k:GetDoorData())
			net.Send(ply)
		end
	end)

	-- Saving!
	nzu.AddSaveExtension("Doors", {
		Save = function()
			local doordata = {}
			local doorents = {}
			for k,v in pairs(doors) do
				if IsValid(k) then
					table.insert(doorents, k)
					table.insert(doordata, k:GetDoorData())
				end
			end

			return doordata, doorents
		end,
		Load = function(doordata, doorents)
			for k,v in pairs(doordata) do
				local ent = doorents[k]
				if IsValid(ent) then
					ent:CreateDoor(v)
				end
			end
		end
	})
else
	net.Receive("nzu_doors", function()
		local ent = net.ReadEntityQueued()
		if net.ReadBool() then
			local tbl = {}
			tbl.Price = net.ReadUInt(32)
			if net.ReadBool() then
				tbl.Electricity = true
			end
			if net.ReadBool() then
				tbl.FlagOpen = true
			end
			if net.ReadBool() then
				tbl.Group = net.ReadString()
			end

			local num = net.ReadUInt(8)
			if num > 0 then
				tbl.Rooms = {}
				for i = 1, num do
					table.insert(tbl.Rooms, net.ReadString())
				end
			end

			if IsValid(ent) then -- If it's valid, then it's the entity directly read from the read
				ent.nzu_DoorData = tbl
				hook.Run("nzu_DoorLockCreated", e, tbl)
			else
				ent:Run(function(e) -- Otherwise it's a structure with a single function "Run" which sets the function to run once the entity becomes valid
					e.nzu_DoorData = tbl
					hook.Run("nzu_DoorLockCreated", e, tbl)
				end)
			end			
		else
			if IsValid(ent) then
				ent.nzu_DoorData = nil
				hook.Run("nzu_DoorLockRemoved", e)
			else
				ent:Run(function(e)
					e.nzu_DoorData = nil
				hook.Run("nzu_DoorLockRemoved", e)
				end)
			end
		end
	end)

	-- Draw door to text
	hook.Add("nzu_GetTargetIDText", "nzu_Doors_TargetID", function(ent)
		local data = ent:GetDoorData()
		if data then
			if ent.nzu_DoorHooked then
				return "This will be opened with Group ["..data.Group.."]"
			end

			local str = "Locked Door ["..data.Price.."]"
			if data.Group then
				str = str .. "[Group: "..data.Group.."]"
			end
			if data.Electricity then
				str = str .. "[Requires Electricity]"
			end
			return str
		end
	end)
end


--[[-------------------------------------------------------------------------
Tool!
---------------------------------------------------------------------------]]
local TOOL = {}
TOOL.Category = "Mapping"
TOOL.Name = "#tool.nzu_tool_doorlock.name"

TOOL.ClientConVar = {
	["price"] = "1000",
	["group"] = "",
	["electricity"] = "0",
	["rooms"] = "",
	["flagopen"] = "0",
}

function TOOL:LeftClick(trace)
	if IsValid(trace.Entity) then
		if trace.Entity:CanCreateDoor() then
			if SERVER then
				local flags = self:GetClientInfo("rooms")
				local tbl
				if flags ~= "" then
					tbl = string.Explode(" ", string.Trim(flags))
				end
				local data = {
					Price = self:GetClientNumber("price"),
					Group = self:GetClientInfo("group"),
					Electricity = self:GetClientNumber("electricity") ~= 0,
					Rooms = tbl,
					FlagOpen = self:GetClientNumber("flagopen") ~= 0,
				}
				trace.Entity:CreateDoor(data)
			end

			return true
		elseif SERVER then
			self:GetOwner():ChatPrint("This entity does not support Locks.")
		end
	end
end

function TOOL:RightClick(trace)
	if IsValid(trace.Entity) then
		local data = trace.Entity:GetDoorData()
		if data then
			if SERVER then
				local owner = self:GetOwner()
				owner:ConCommand("nzu_tool_doorlock_price "..data.Price)
				owner:ConCommand("nzu_tool_doorlock_group \""..(data.Group or "\""))
				owner:ConCommand("nzu_tool_doorlock_electricity "..(data.Electricity and "1" or "0"))
				owner:ConCommand("nzu_tool_doorlock_flagopen "..(data.FlagOpen and "1" or "0"))

				local str = ""
				if data.Rooms then
					for k,v in pairs(data.Rooms) do
						str = str .. v .. " "
					end
					str = string.Trim(str)
				end
				owner:ConCommand("nzu_tool_doorlock_rooms \""..str.."\"")
				owner:ChatPrint("Copied door data!")
			end
			return true
		end
	end
end

function TOOL:Reload(trace)
	if IsValid(trace.Entity) and trace.Entity:GetDoorData() then
		if SERVER then trace.Entity:RemoveDoor() end
		return true
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left"},
		{name = "right"},
		{name = "reload"},
	}

	language.Add("tool.nzu_tool_doorlock.name", "Door Lock Creator")
	language.Add("tool.nzu_tool_doorlock.desc", "Creates Locks on props and doors that can be bought by players in-game.")

	language.Add("tool.nzu_tool_doorlock.left", "Create Lock")
	language.Add("tool.nzu_tool_doorlock.right", "Copy Lock from target door")
	language.Add("tool.nzu_tool_doorlock.reload", "Remove Lock")

	function TOOL.BuildCPanel(panel)
		panel:Help("Create Locks on props and doors that can be bought in-game.\nTip: You can type in a custom price in the text.")

		local slider = panel:NumSlider("Price", "nzu_tool_doorlock_price", 0, 5000, 0)
		function slider:TranslateSliderValues(x,y)
			local val = self.Scratch:GetMin() + x*self.Scratch:GetRange()

			val = math.Round(val, -2) -- This rounds to nearest 100

			self:SetValue(val)
			return self.Scratch:GetFraction(), y
		end
		panel:CheckBox("Requires Electricity?", "nzu_tool_doorlock_electricity")

		panel:TextEntry("Door Group", "nzu_tool_doorlock_group")
		panel:Help("Door Groups all open together when any of them are bought. Leave empty for none.")
		
		panel:Help("")

		panel:ControlHelp("Select which Rooms are opened by the door. This enables Spawners and other Room enabled entities assigned to these. Usually Doors want to select 2 Rooms (one for either side of the door).")

		local listbox = vgui.Create("nzu_RoomsPanel", panel)
		listbox:SetConVar("nzu_tool_doorlock_rooms")
		panel:AddItem(listbox)
		listbox:RefreshRooms()

		panel:ControlHelp("Room names cannot contain spaces.")

		panel:CheckBox("Open if all Rooms are open?", "nzu_tool_doorlock_flagopen")
		panel:ControlHelp("Opens the door for free if all connected Rooms are opened through other doors.")
	end
end

nzu.RegisterTool("doorlock", TOOL)


--[[-------------------------------------------------------------------------
Property (Context Menu)
---------------------------------------------------------------------------]]
properties.Add("nzu_DoorLock", {
	MenuLabel = "[NZU] Edit Door Lock",
	Order = 3000,
	MenuIcon = "icon16/lock.png",
	PrependSpacer = true,

	Filter = function(self, ent, ply) -- A function that determines whether an entity is valid for this property
		if not IsValid(ent) then return false end
		if not gamemode.Call("CanProperty", ply, "nzu_DoorLock", ent) then return false end

		return ent:GetDoorData() or ent:CanCreateDoor()
	end,
	Receive = function(self, length, player)
		local ent = net.ReadEntity()
		if not self:Filter(ent, player) then return end

		local tbl = {}
		tbl.Price = net.ReadUInt(32)
		if net.ReadBool() then
			tbl.Electricity = true
		end
		if net.ReadBool() then
			tbl.FlagOpen = true
		end

		if net.ReadBool() then
			tbl.Group = net.ReadString()
		end

		local num = net.ReadUInt(8)
		if num > 0 then
			tbl.Rooms = {}
			for i = 1,num do
				table.insert(tbl.Rooms, net.ReadString())
			end
		end

		ent:CreateDoor(tbl)
	end,
	Action = function(self, ent) -- Chance the clientside action to request a panel update
		local frame = vgui.Create("DFrame")
		frame:SetSize(300,400)
		frame:SetTitle("Edit Door Lock")
		frame:SetDeleteOnClose(true)
		frame:ShowCloseButton(false)
		frame:SetBackgroundBlur(true)
		frame:SetDrawOnTop(true)

		local top = frame:Add("DProperties")
		top:Dock(TOP)
		top:SetTall(100)
		top:DockMargin(0,0,0,10)

		local data = ent:GetDoorData()

		local val_price = data and data.Price or 1000
		local price = top:CreateRow("Lock Properties", "Price")
		price:Setup("Int", {min = 0, max = 5000})
		price:SetValue(val_price)
		function price:DataChanged(v)
			val_price = v
		end

		local val_group = data and data.Group or ""
		local group = top:CreateRow("Lock Properties", "Door Group")
		group:Setup("Generic")
		group:SetValue(val_group)
		function group:DataChanged(v) val_group = v end

		local val_elec = data and data.Electricity
		local elec = top:CreateRow("Lock Properties", "Requires Electricity?")
		elec:Setup("Boolean")
		elec:SetValue(val_elec)
		function elec:DataChanged(v) val_elec = v end

		local lbl = frame:Add("DLabel")
		lbl:Dock(TOP)
		lbl:SetFont("Trebuchet18")
		lbl:SetText("Connected Rooms")

		local l = frame:Add("nzu_RoomsPanel")
		l:Dock(FILL)
		l:ShowRefreshButton(false)
		l:SetSelectedRooms(data and data.Rooms)
		l:RefreshRooms()

		local val_flagopen = data and data.FlagOpen
		local roomopen = top:CreateRow("Lock Properties", "Open if all Rooms are open?")
		roomopen:Setup("Boolean")
		roomopen:SetValue(val_flagopen)
		function roomopen:DataChanged(v) val_flagopen = v end

		local bottom = frame:Add("Panel")
		bottom:Dock(BOTTOM)
		bottom:SetTall(30)
		bottom:DockMargin(0,10,0,0)
		bottom:DockPadding(5,5,5,2)

		local save = bottom:Add("DButton")
		save:Dock(LEFT)
		save:SetText("Apply")
		save:SetWide(125)
		save.DoClick = function()
			self:MsgStart()
				net.WriteEntity(ent)
				net.WriteUInt(val_price, 32)
				net.WriteBool(val_elec)
				net.WriteBool(val_flagopen)

				if val_group and val_group ~= "" then
					net.WriteBool(true)
					net.WriteString(val_group)
				else
					net.WriteBool(false)
				end

				local flags = l:GetSelectedRooms()
				net.WriteUInt(#flags, 8)
				for k,v in pairs(flags) do
					net.WriteString(v)
				end
			self:MsgEnd()

			frame:Close()
		end

		local cancel = bottom:Add("DButton")
		cancel:Dock(RIGHT)
		cancel:SetText("Cancel")
		cancel:SetWide(125)
		cancel.DoClick = function()
			frame:Close()
		end

		frame:Center()
		frame:MakePopup()
		frame:DoModal()
	end
})