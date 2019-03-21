local ENTITY = FindMetaTable("Entity")


if SERVER then
	local flags = {}
	function nzu.GetMapFlagsList() return table.GetKeys(flags) end	

	function ENTITY:EnableMapFlags(id)
		self.nzu_MapFlagsHandler = id
		if not self.nzu_MapFlags then self.nzu_MapFlags = {} end
	end

	function ENTITY:DisableMapFlags()
		if self.nzu_MapFlagsHandler and self.nzu_MapFlags then
			for k,v in pairs(self.nzu_MapFlags) do
				flags[k][self] = nil
			end
			self.nzu_MapFlagsHandler = nil
			self.nzu_MapFlags = nil
		end
	end

	local handlers = {}
	function nzu.AddMapFlagsHandler(id, handler)
		if NZU_NZOMBIES then handlers[id] = handler end -- Handlers have no use in Sandbox
	end

	function ENTITY:AddMapFlag(flag)
		assert(self.nzu_MapFlagsHandler, "Attempted to add a Map Flag to entity without enabled Map Flags.")

		if not flags[flag] then flags[flag] = {} end
		flags[flag][self] = true
		self.nzu_MapFlags[flag] = true
	end

	function ENTITY:RemoveMapFlag(flag)
		assert(self.nzu_MapFlagsHandler, "Attempted to remove a Map Flag to entity without enabled Map Flags.")

		if flags[flag] then
			flags[flag][self] = nil
			if next(flags[flag]) == nil then
				flags[flag] = nil
			end
		end
		self.nzu_MapFlags[flag] = nil
	end

	function ENTITY:SetMapFlags(flags)
		local olds = table.Copy(self.nzu_MapFlags)

		for k,v in pairs(flags) do
			if not olds[v] then
				self:AddMapFlag(v)
			end
			olds[v] = nil
		end

		for k,v in pairs(olds) do -- Now only those who were there before, but not now
			self:RemoveMapFlag(k)
		end
	end

	function ENTITY:GetMapFlags()
		return self.nzu_MapFlags and table.GetKeys(self.nzu_MapFlags)
	end

	-- Respond to net requests, but only in sandbox
	if NZU_SANDBOX then
		util.AddNetworkString("nzu_mapflags")
		net.Receive("nzu_mapflags", function(len, ply)
			if net.ReadBool() then
				local ent = net.ReadEntity()
				if IsValid(ent) then
					local flags = nzu.GetMapFlagsList()
					local num = table.Count(flags)

					net.Start("nzu_mapflags")
						net.WriteBool(true)
						net.WriteEntity(ent)

						net.WriteUInt(num, 8)
						for k,v in pairs(flags) do
							net.WriteString(v)
							net.WriteBool(ent.nzu_MapFlags and ent.nzu_MapFlags[v])
						end
					net.Send(ply)
				end
			else
				local flags = nzu.GetMapFlagsList()
				local num = table.Count(flags)
				net.Start("nzu_mapflags")
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
		local openedflags = {}
		function nzu.OpenMapFlag(flag)
			openedflags[flag] = true
			if flags[flag] then
				for k,v in pairs(flags[flag]) do
					if IsValid(k) then
						local handler = k.nzu_MapFlagsHandler and handlers[k.nzu_MapFlagsHandler]
						if handler then
							handler(k)
						end

						-- Clear this from the handler
						k.nzu_MapFlagsHandler = nil
						k.nzu_MapFlags = nil
					end
				end
				flags[flag] = nil -- No longer retain these flags
			end
		end

		function nzu.IsMapFlagOpen(flag)
			return openedflags[flag]
		end
	end

	-- Cleanup if entities are removed
	hook.Add("EntityRemoved", "nzu_MapFlagsRemoval", function(ent)
		if ent.nzu_MapFlags then
			for k,v in pairs(ent.nzu_MapFlags) do
				if flags[v] then
					flags[v][ent] = nil
					if next(flags[v]) == nil then
						flags[v] = nil
					end
				end
			end
		end
	end)
else
	function ENTITY:EnableMapFlags(id) -- Client mirror, just so clients know what type of map flags group this belongs to
		self.nzu_MapFlagsHandler = id
	end
end

--[[-------------------------------------------------------------------------
Client editing support
- Panels for selecting from available flags (Use in tools)
- A property entry to edit flags of an entity (Context menu right-click)
---------------------------------------------------------------------------]]

if CLIENT then
	-- Panel
	local PANEL = {}

	function PANEL:Init()
		local bottom = self:Add("Panel")
		bottom:SetTall(20)
		bottom:DockMargin(0,5,0,0)
		bottom:Dock(BOTTOM)
		self.NewFlagButton = bottom:Add("DButton")
		self.NewFlagButton:SetText("Add new Flag")
		self.NewFlagButton:Dock(RIGHT)
		self.NewFlagButton:SetWide(100)
		self.NewFlagButton:DockMargin(5,0,0,0)

		self.NewFlagEntry = bottom:Add("DTextEntry")
		self.NewFlagEntry:SetPlaceholderText("Enter new flag ...")
		self.NewFlagEntry:Dock(FILL)
		self.NewFlagButton.DoClick = function()
			local str = self.NewFlagEntry:GetText()
			if str ~= "" and not string.find(str, " ") then
				self:AddNewFlag(str, true)
				self.NewFlagEntry:SetText("")
			else
				self.NewFlagEntry.ErrorHighlight = 255
			end
		end

		self.NewFlagEntry.PaintOver = function(s,w,h)
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
			self:RefreshFlags()
		end

		self.List = self:Add("DListView")
		self.List:SetMultiSelect(true)
		self.List:AddColumn("Flag")
		self.List:Dock(FILL)
		self.List.OnClickLine = self.OnClickLine

		self:SetTall(300)
		self:SetPaintBackground(false)
	end

	function PANEL:OnClickLine(Line, bClear) -- Copied from DListView but modified to check overall change too
		local bMultiSelect = self:GetMultiSelect()
		if ( !bMultiSelect && !bClear ) then return end

		--
		-- Control, multi select
		--
		if ( bMultiSelect && input.IsKeyDown( KEY_LCONTROL ) ) then
			bClear = false
		end

		--
		-- Shift block select
		--
		if ( bMultiSelect && input.IsKeyDown( KEY_LSHIFT ) ) then

			local Selected = self:GetSortedID( self:GetSelectedLine() )
			if ( Selected ) then
				local anychange = false -- This is new
				local LineID = self:GetSortedID( Line:GetID() )

				local First = math.min( Selected, LineID )
				local Last = math.max( Selected, LineID )

				-- Fire off OnRowSelected for each non selected row
				for id = First, Last do
					local line = self.Sorted[ id ]
					if ( !line:IsLineSelected() ) then self:OnRowSelected( line:GetID(), line ) anychange = true end
					line:SetSelected( true )
				end

				-- Clear the selection and select only the required rows
				if ( bClear ) then self:ClearSelection() end

				for id = First, Last do
					local line = self.Sorted[ id ]
					line:SetSelected( true )
				end

				if anychange then
					self:GetParent():OnSelectedFlagsChanged()
				end

				return

			end

		end

		--
		-- Check for double click
		--
		if ( Line:IsSelected() && Line.m_fClickTime && ( !bMultiSelect || bClear ) ) then

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

		if ( !bMultiSelect || bClear ) then
			if b and table.Count(self:GetSelected()) > 1 then
				b = false
			end
			self:ClearSelection()
		end

		b = not b
		Line:SetSelected(b)
		Line.m_fClickTime = SysTime()

		if b then self:OnRowSelected(Line:GetID(), Line) end
		self:GetParent():OnSelectedFlagsChanged()
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
		self.NewFlagEntry:SetDisabled(disable)
		self.NewFlagButton:SetDisabled(disable)
		self.RefreshButton:SetDisabled(disable)
	end

	function PANEL:LoadFlagsSelected(flags)
		self.List:Clear()
		for k,v in pairs(flags) do
			local p = self:AddLine(k)
			p:SetSelected(v)
		end

		self:OnSelectedFlagsChanged()

		self.ControlHelp:SetText("Use Shift/Ctrl to select multiple.")
		self.List:SetDisabled(self.m_bDisabled)
		self.NewFlagEntry:SetDisabled(self.m_bDisabled)
		self.NewFlagButton:SetDisabled(self.m_bDisabled)
		self.RefreshButton:SetDisabled(self.m_bDisabled)

		self.RefreshGiveUp = nil
	end

	local function emptyfunc() end
	function PANEL:AddLine(...)
		local line = self.List:AddLine(...)
		line.OnCursorMoved = emptyfunc
		return line
	end

	function PANEL:LoadFlags(tbl)
		local selectedflags = {}
		for k,v in pairs(self:GetSelectedFlags()) do
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

		if next(selectedflags) then -- The table is non-empty: We removed a previously selected element. Update selection callback.
			self:OnSelectedFlagsChanged()
		end

		self.ControlHelp:SetText("Use Shift/Ctrl to select multiple.")
		self.List:SetDisabled(self.m_bDisabled)
		self.NewFlagEntry:SetDisabled(self.m_bDisabled)
		self.NewFlagButton:SetDisabled(self.m_bDisabled)
		self.RefreshButton:SetDisabled(self.m_bDisabled)

		self.RefreshGiveUp = nil
	end

	function PANEL:AddNewFlag(str, selected)
		for k,v in pairs(self.List:GetLines()) do
			if v:GetColumnText(1) == str then
				if not v:IsSelected() and selected then
					v:SetSelected(true)
					self:OnSelectedFlagsChanged()
				end
				return
			end
		end

		self:AddLine(str):SetSelected(selected)
		if selected then self:OnSelectedFlagsChanged() end
	end

	function PANEL:GetSelectedFlags()
		local flags = {}
		for k,v in pairs(self.List:GetSelected()) do
			table.insert(flags, v:GetColumnText(1))
		end

		return flags
	end

	function PANEL:SetSelectedFlags(flags)
		local keys = {}
		for k,v in pairs(flags) do
			keys[v] = true
		end

		for k,v in pairs(self.List:GetLines()) do
			local key = v:GetColumnText(1)
			if keys[key] then
				v:SetSelected(true)
				keys[key] = nil
			end
		end

		-- Add all flags that aren't already in there
		for k,v in pairs(keys) do
			self:AddNewFlag(k, true)
		end

		self:OnSelectedFlagsChanged()
	end

	local torefresh
	function PANEL:RefreshFlags(ent) -- Optional ent: Select this entity's flags too
		local donet = false
		if ent then
			if not ent.nzu_MapFlagsPanelRefresh then
				ent.nzu_MapFlagsPanelRefresh = {}
				donet = true
			end
			ent.nzu_MapFlagsPanelRefresh[self] = true
		else
			if not torefresh then
				torefresh = {}
				donet = true
			end
			torefresh[self] = true
		end
		

		if donet then
			net.Start("nzu_mapflags")
				if IsValid(ent) then
					net.WriteBool(true)
					net.WriteEntity(ent)
				else
					net.WriteBool(false)
				end
			net.SendToServer()
		end

		self.ControlHelp:SetText("Refreshing flags ...")
		self.List:SetDisabled(true)
		self.NewFlagEntry:SetDisabled(true)
		self.NewFlagButton:SetDisabled(true)
		self.RefreshButton:SetDisabled(true)

		self.RefreshGiveUp = CurTime() + 5
	end

	function PANEL:ShowRefreshButton(b)
		self.RefreshButton:SetVisible(b)
	end

	function PANEL:Think()
		if self.RefreshGiveUp and self.RefreshGiveUp < CurTime() then
			self.ControlHelp:SetText("Couldn't retrieve flags")
			self.List:SetDisabled(self.m_bDisabled)
			self.NewFlagEntry:SetDisabled(self.m_bDisabled)
			self.NewFlagButton:SetDisabled(self.m_bDisabled)
			self.RefreshButton:SetDisabled(self.m_bDisabled)

			if torefresh then torefresh[self] = nil end
			self.RefreshGiveUp = nil
		end
	end

	function PANEL:OnSelectedFlagsChanged()
		-- Implement me!
	end

	net.Receive("nzu_mapflags", function()
		if net.ReadBool() then
			local ent = net.ReadEntity()
			if IsValid(ent) then
				local num = net.ReadUInt(8)
				local tbl = {}
				for i = 1,num do
					local str = net.ReadString()
					tbl[str] = net.ReadBool()
				end

				for k,v in pairs(ent.nzu_MapFlagsPanelRefresh) do
					k:LoadFlagsSelected(tbl)
				end
				ent.nzu_MapFlagsPanelRefresh = nil
			end
		elseif torefresh then
			local num = net.ReadUInt(8)
			local tbl = {}
			for i = 1,num do
				table.insert(tbl, net.ReadString())
			end

			for k,v in pairs(torefresh) do
				k:LoadFlags(tbl)
			end

			torefresh = nil
		end
	end)
	vgui.Register("nzu_MapFlagsPanel", PANEL, "DPanel")
end

if NZU_SANDBOX then
	-- A property that lets you modify the flags of a selected entity
	-- Works for any entity that has self.nzu_MapFlagsHandler field set
	-- (i.e. Entity:EnableMapFlags())

	properties.Add("nzu_MapFlags", {
		MenuLabel = "[NZU] Edit Map Flags",
		Order = 3100,
		MenuIcon = "icon16/door_open.png",
		--PrependSpacer = true,

		Filter = function(self, ent, ply) -- A function that determines whether an entity is valid for this property
			if !IsValid(ent) then return false end
			if !gamemode.Call("CanProperty", ply, "nzu_MapFlags", ent) then return false end

			return ent.nzu_MapFlagsHandler
		end,
		Receive = function(self, length, player)
			local ent = net.ReadEntity()
			if !self:Filter(ent, player) then return end

			local num = net.ReadUInt(8)
			local tbl = {}
			for i = 1,num do
				table.insert(tbl, net.ReadString())
			end

			ent:SetMapFlags(tbl)
		end,
		Action = function(self, ent) -- Chance the clientside action to request a panel update
			local frame = vgui.Create("DFrame")
			frame:SetSize(300,400)
			frame:SetTitle("Edit Map Flags")
			frame:SetDeleteOnClose(true)
			frame:ShowCloseButton(false)
			frame:SetBackgroundBlur(true)
			frame:SetDrawOnTop(true)

			local l = frame:Add("nzu_MapFlagsPanel")
			l:Dock(FILL)
			l:ShowRefreshButton(false)
			l:RefreshFlags(ent)

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
				local flags = l:GetSelectedFlags()

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