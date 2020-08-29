local ENTITY = FindMetaTable("Entity")


if SERVER then
	local rooms = {}
	function nzu.GetRoomList() return table.GetKeys(rooms) end

	function ENTITY:AddRoom(flag)
		if not rooms[flag] then rooms[flag] = {} end
		rooms[flag][self] = true

		if not self.nzu_Rooms then self.nzu_Rooms = {} end
		self.nzu_Rooms[flag] = true
	end

	function ENTITY:RemoveRoom(flag)
		if rooms[flag] then
			rooms[flag][self] = nil
			if next(rooms[flag]) == nil then
				rooms[flag] = nil
			end
		end
		self.nzu_Rooms[flag] = nil
		if table.IsEmpty(self.nzu_Rooms) then self.nzu_Rooms = nil end
	end

	function ENTITY:SetRooms(flags)
		if not self.nzu_Rooms then
			for k,v in pairs(flags) do
				self:AddRoom(v)
			end
		else
			local flags = {}

			for k,v in pairs(flags) do
				if not self.nzu_Rooms[v] then
					self:AddRoom(v)
				end
				flags[v] = true
			end

			for k,v in pairs(self.nzu_Rooms) do -- Now only those who were there before, but not anymore
				if not found[k] then
					self:RemoveRoom(k)
				end
			end
		end
	end

	function ENTITY:GetRooms()
		return self.nzu_Rooms and table.GetKeys(self.nzu_Rooms)
	end

	-- Respond to net requests, but only in sandbox
	if NZU_SANDBOX then
		util.AddNetworkString("nzu_rooms")
		net.Receive("nzu_rooms", function(len, ply)
			if net.ReadBool() then
				local ent = net.ReadEntity()
				if IsValid(ent) then
					local flags = nzu.GetRoomList()
					local num = table.Count(flags)

					net.Start("nzu_rooms")
						net.WriteBool(true)
						net.WriteEntity(ent)

						net.WriteUInt(num, 8)
						for k,v in pairs(flags) do
							net.WriteString(v)
							net.WriteBool(ent.nzu_Rooms and ent.nzu_Rooms[v])
						end
					net.Send(ply)
				end
			else
				local flags = nzu.GetRoomList()
				local num = table.Count(flags)
				net.Start("nzu_rooms")
					net.WriteBool(false)
					net.WriteUInt(num, 8)
					for k,v in pairs(flags) do
						net.WriteString(v)
					end
				net.Send(ply)
			end
		end)
	end

	if NZU_NZOMBIES then
		local openedrooms = {}
		function nzu.OpenRoom(flag)
			openedrooms[flag] = true
			if rooms[flag] then
				local ent = rooms[flag]
				rooms[flag] = nil -- No longer retain these flags

				for k,v in pairs(ent) do
					if IsValid(k) and k.nzu_Rooms then
						local handler = k.OnRoomOpened
						if not handler or not handler(k, flag) then
							-- Clear the rooms if it has either no function, or the function didn't return true
							-- If the function returns true, it retains the flags (opening again with the rest of the flags associated to it)
							k.nzu_Rooms = nil
						end
					end
				end
			end
		end

		hook.Add("nzu_PostConfigMap", "nzu_Rooms_ResetOpenRooms", function()
			openedrooms = {}
		end)

		function nzu.IsRoomOpen(flag)
			return openedrooms[flag] or false
		end
	end

	-- Cleanup if entities are removed
	hook.Add("EntityRemoved", "nzu_RoomsRemoval", function(ent)
		if ent.nzu_Rooms then
			for k,v in pairs(ent.nzu_Rooms) do
				if rooms[v] then
					rooms[v][ent] = nil
					if next(rooms[v]) == nil then
						rooms[v] = nil
					end
				end
			end
		end
	end)
end

--[[-------------------------------------------------------------------------
Client editing support
- Panels for selecting from available rooms (Use in tools)
- A property entry to edit rooms of an entity (Context menu right-click)
---------------------------------------------------------------------------]]

if CLIENT then
	-- Panel
	local PANEL = {}

	Derma_Install_Convar_Functions(PANEL)

	function PANEL:Init()
		local bottom = self:Add("Panel")
		bottom:SetTall(20)
		bottom:DockMargin(0,5,0,0)
		bottom:Dock(BOTTOM)
		self.NewRoomButton = bottom:Add("DButton")
		self.NewRoomButton:SetText("Add new Room")
		self.NewRoomButton:Dock(RIGHT)
		self.NewRoomButton:SetWide(100)
		self.NewRoomButton:DockMargin(5,0,0,0)

		self.NewRoomEntry = bottom:Add("DTextEntry")
		self.NewRoomEntry:SetPlaceholderText("Enter new room name ...")
		self.NewRoomEntry:Dock(FILL)
		self.NewRoomButton.DoClick = function()
			local str = self.NewRoomEntry:GetText()
			if str ~= "" and not string.find(str, " ") then
				self:AddNewRoom(str, true)
				self.NewRoomEntry:SetText("")
			else
				self.NewRoomEntry.ErrorHighlight = 255
			end
		end

		self.NewRoomEntry.PaintOver = function(s,w,h)
			if s.ErrorHighlight then
				surface.SetDrawColor(255,0,0,s.ErrorHighlight)
				local x2,y2 = s:GetSize()
				surface.DrawRect(-50, -50, x2+50, y2+50)
				s.ErrorHighlight = s.ErrorHighlight - FrameTime() * 100
				if s.ErrorHighlight <= 0 then
					s.ErrorHighlight = nil
				end
			end
		end

		local top = self:Add("Panel")
		top:Dock(TOP)
		top:SetTall(20)
		top:DockMargin(0,0,0,5)

		self.ControlHelp = top:Add("DLabel")
		self.ControlHelp:SetText("Click Refresh to update list.")
		self.ControlHelp:SetTextColor(color_black)
		self.ControlHelp:Dock(FILL)

		self.RefreshButton = top:Add("DButton")
		self.RefreshButton:Dock(RIGHT)
		self.RefreshButton:SetWide(120)
		self.RefreshButton:SetText("Refresh from Server")
		self.RefreshButton.DoClick = function()
			self:RefreshRooms()
		end

		self.List = self:Add("DListView")
		self.List:SetMultiSelect(true)
		self.List:AddColumn("Room")
		self.List:Dock(FILL)
		self.List.OnClickLine = self.OnClickLine

		self:SetTall(300)
		self:SetPaintBackground(false)
	end

	function PANEL:OnClickLine(Line, bClear) -- Copied from DListView but modified to check overall change too
		local bMultiSelect = self:GetMultiSelect()
		if ( not bMultiSelect and not bClear ) then return end

		--
		-- Control, multi select
		--
		if ( bMultiSelect and input.IsKeyDown( KEY_LCONTROL ) ) then
			bClear = false
		end

		--
		-- Shift block select
		--
		if ( bMultiSelect and input.IsKeyDown( KEY_LSHIFT ) ) then

			local Selected = self:GetSortedID( self:GetSelectedLine() )
			if ( Selected ) then
				local anychange = false -- This is new
				local LineID = self:GetSortedID( Line:GetID() )

				local First = math.min( Selected, LineID )
				local Last = math.max( Selected, LineID )

				-- Fire off OnRowSelected for each non selected row
				for id = First, Last do
					local line = self.Sorted[ id ]
					if ( not line:IsLineSelected() ) then self:OnRowSelected( line:GetID(), line ) anychange = true end
					line:SetSelected( true )
				end

				-- Clear the selection and select only the required rows
				if ( bClear ) then self:ClearSelection() end

				for id = First, Last do
					local line = self.Sorted[ id ]
					line:SetSelected( true )
				end

				if anychange then
					self:GetParent():UpdateConVar()
					self:GetParent():OnSelectedRoomsChanged()
				end

				return

			end

		end

		--
		-- Check for double click
		--
		if ( Line:IsSelected() and Line.m_fClickTime and ( not bMultiSelect or bClear ) ) then

			local fTimeDistance = SysTime() - Line.m_fClickTime

			if ( fTimeDistance < 0.3 ) then
				self:DoDoubleClick( Line:GetID(), Line )
				return
			end

		end

		--
		-- If it's a new mouse click, or this isn't
		-- multiselect we clear the selection
		--
		local b = Line:IsSelected()

		if ( not bMultiSelect or bClear ) then
			if b and table.Count(self:GetSelected()) > 1 then
				b = false
			end
			self:ClearSelection()
		end

		b = not b
		Line:SetSelected(b)
		Line.m_fClickTime = SysTime()

		if b then self:OnRowSelected(Line:GetID(), Line) end
		self:GetParent():UpdateConVar()
		self:GetParent():OnSelectedRoomsChanged()
	end

	function PANEL:SetDisabled(disable)
		self.m_bDisabled = disable

		if disable then
			self:SetAlpha(75)
			self:SetMouseInputEnabled(false)
		else
			self:SetAlpha(255)
			self:SetMouseInputEnabled(true)
		end

		self.List:SetDisabled(disable)
		self.NewRoomEntry:SetDisabled(disable)
		self.NewRoomButton:SetDisabled(disable)
		self.RefreshButton:SetDisabled(disable)
	end

	function PANEL:LoadRoomsSelected(flags)
		self.List:Clear()

		for k,v in pairs(flags) do
			local p = self:AddLine(k)
			p:SetSelected(v)
		end

		self:UpdateConVar()
		self:OnSelectedRoomsChanged()

		self.ControlHelp:SetText("Use Shift/Ctrl to select multiple.")
		self.List:SetDisabled(self.m_bDisabled)
		self.NewRoomEntry:SetDisabled(self.m_bDisabled)
		self.NewRoomButton:SetDisabled(self.m_bDisabled)
		self.RefreshButton:SetDisabled(self.m_bDisabled)

		self.RefreshGiveUp = nil
	end

	local function emptyfunc() end
	function PANEL:AddLine(...)
		local line = self.List:AddLine(...)
		line.OnCursorMoved = emptyfunc
		return line
	end

	function PANEL:LoadRooms(tbl)
		local selectedflags = {}
		for k,v in pairs(self:GetSelectedRooms()) do
			selectedflags[v] = true
		end

		self.List:Clear()
		for k,v in pairs(tbl) do
			local p = self:AddLine(v)
			if selectedflags[v] then
				p:SetSelected(true)
				selectedflags[v] = nil
			end
		end

		for k,v in pairs(selectedflags) do
			local p = self:AddLine(k)
			p:SetSelected(true) -- Re-add old selected lines
		end

		self.ControlHelp:SetText("Use Shift/Ctrl to select multiple.")
		self.List:SetDisabled(self.m_bDisabled)
		self.NewRoomEntry:SetDisabled(self.m_bDisabled)
		self.NewRoomButton:SetDisabled(self.m_bDisabled)
		self.RefreshButton:SetDisabled(self.m_bDisabled)

		self.RefreshGiveUp = nil
	end

	function PANEL:AddNewRoom(str, selected)
		for k,v in pairs(self.List:GetLines()) do
			if v:GetColumnText(1) == str then
				if not v:IsSelected() and selected then
					v:SetSelected(true)
					self:UpdateConVar()
					self:OnSelectedRoomsChanged()
				end
				return
			end
		end

		self:AddLine(str):SetSelected(selected)
		if selected then
			self:UpdateConVar()
			self:OnSelectedRoomsChanged()
		end
	end

	function PANEL:GetSelectedRooms()
		local flags = {}
		for k,v in pairs(self.List:GetSelected()) do
			table.insert(flags, v:GetColumnText(1))
		end

		return flags
	end

	function PANEL:SetSelectedRooms(flags)
		local flags = flags or {}
		local keys = {}
		for k,v in pairs(flags) do
			keys[v] = true
		end

		--local toremove = {}
		for k,v in pairs(self.List:GetLines()) do
			local key = v:GetColumnText(1)
			if keys[key] then
				v:SetSelected(true)
				keys[key] = nil
			else
				v:SetSelected(false) -- It's loaded but not selected
			end
		end

		--for k,v in pairs(toremove) do
			--self.List:RemoveLine(v)
		--end

		-- Add all flags that aren't already in there
		for k,v in pairs(keys) do
			self:AddNewRoom(k, true)
		end

		self:UpdateConVar()
		self:OnSelectedRoomsChanged()
	end

	local torefresh
	function PANEL:RefreshRooms(ent) -- Optional ent: Select this entity's flags too
		local donet = false
		if ent then
			if not ent.nzu_RoomsPanelRefresh then
				ent.nzu_RoomsPanelRefresh = {}
				donet = true
			end
			ent.nzu_RoomsPanelRefresh[self] = true
		else
			if not torefresh then
				torefresh = {}
				donet = true
			end
			torefresh[self] = true
		end
		

		if donet then
			net.Start("nzu_rooms")
				if IsValid(ent) then
					net.WriteBool(true)
					net.WriteEntity(ent)
				else
					net.WriteBool(false)
				end
			net.SendToServer()
		end

		self.ControlHelp:SetText("Refreshing rooms ...")
		self.List:SetDisabled(true)
		self.NewRoomEntry:SetDisabled(true)
		self.NewRoomButton:SetDisabled(true)
		self.RefreshButton:SetDisabled(true)

		self.RefreshGiveUp = CurTime() + 5
	end

	function PANEL:ShowRefreshButton(b)
		self.RefreshButton:SetVisible(b)
	end

	function PANEL:Think()
		if self.RefreshGiveUp and self.RefreshGiveUp < CurTime() then
			self.ControlHelp:SetText("Couldn't retrieve rooms")
			self.List:SetDisabled(self.m_bDisabled)
			self.NewRoomEntry:SetDisabled(self.m_bDisabled)
			self.NewRoomButton:SetDisabled(self.m_bDisabled)
			self.RefreshButton:SetDisabled(self.m_bDisabled)

			if torefresh then torefresh[self] = nil end
			self.RefreshGiveUp = nil
		end

		self:ConVarStringThink()
	end

	function PANEL:SetValue(str) -- Setting via string
		local str2 = string.Trim(str)
		local tbl = str2 == "" and {} or string.Explode(" ", str2)

		self.m_bIgnoreConVar = true
		self.m_strConVarValue = str
		self:SetSelectedRooms(tbl)
		self.m_bIgnoreConVar = nil
	end

	function PANEL:UpdateConVar() -- Update its ConVar
		if self.m_strConVar and not self.m_bIgnoreConVar then
			local str = ""
			for k,v in pairs(self:GetSelectedRooms()) do
				str = str .. v .. " "
			end
			str = string.Trim(str)
			self:ConVarChanged(str)
		end
	end

	function PANEL:OnSelectedRoomsChanged()
		-- Implement me!
	end

	net.Receive("nzu_rooms", function()
		if net.ReadBool() then
			local ent = net.ReadEntity()
			if IsValid(ent) then
				local num = net.ReadUInt(8)
				local tbl = {}
				for i = 1,num do
					local str = net.ReadString()
					tbl[str] = net.ReadBool()
				end

				for k,v in pairs(ent.nzu_RoomsPanelRefresh) do
					k:LoadRoomsSelected(tbl)
				end
				ent.nzu_RoomsPanelRefresh = nil
			end
		elseif torefresh then
			local num = net.ReadUInt(8)
			local tbl = {}
			for i = 1,num do
				table.insert(tbl, net.ReadString())
			end

			for k,v in pairs(torefresh) do
				k:LoadRooms(tbl)
			end

			torefresh = nil
		end
	end)
	vgui.Register("nzu_RoomsPanel", PANEL, "DPanel")
end

if NZU_SANDBOX then
	-- A property that lets you modify the rooms of a selected entity
	-- Works for any entity that has self.OnRoomOpened function set

	properties.Add("nzu_Rooms", {
		MenuLabel = "[NZU] Edit Room",
		Order = 3100,
		MenuIcon = "icon16/door_open.png",
		--PrependSpacer = true,

		Filter = function(self, ent, ply) -- A function that determines whether an entity is valid for this property
			if not IsValid(ent) then return false end
			if not gamemode.Call("CanProperty", ply, "nzu_Rooms", ent) then return false end

			return ent.OnRoomOpened
		end,
		Receive = function(self, length, player)
			local ent = net.ReadEntity()
			if not self:Filter(ent, player) then return end

			local num = net.ReadUInt(8)
			local tbl = {}
			for i = 1,num do
				table.insert(tbl, net.ReadString())
			end

			ent:SetRooms(tbl)
		end,
		Action = function(self, ent) -- Chance the clientside action to request a panel update
			local frame = vgui.Create("DFrame")
			frame:SetSize(300,400)
			frame:SetTitle("Edit Room")
			frame:SetDeleteOnClose(true)
			frame:ShowCloseButton(false)
			frame:SetBackgroundBlur(true)
			frame:SetDrawOnTop(true)

			local l = frame:Add("nzu_RoomsPanel")
			l:Dock(FILL)
			l:ShowRefreshButton(false)
			l:RefreshRooms(ent)

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
				local flags = l:GetSelectedRooms()

				self:MsgStart()
					net.WriteEntity(ent)
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
end