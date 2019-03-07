-- Needed for Properties.Add
local property = {
	MenuLabel = "[NZU] Edit Map Flags",
	Order = 100,
	MenuIcon = "icon16/door_open.png",
	PrependSpacer = true,

	Filter = function(self, ent, ply) -- A function that determines whether an entity is valid for this property
		if !IsValid(ent) then return false end
		if !gamemode.Call("CanProperty", ply, "ignite", ent) then return false end

		return ent.nzu_MapFlagsHandler
	end,
	Action = function(self, ent) -- The action to perform upon using the property (Clientside)
		
		self:MsgStart()
			net.WriteEntity( ent )
		self:MsgEnd()

	end,
	Receive = function( self, length, player ) -- The action to perform upon using the property ( Serverside )
		local ent = net.ReadEntity()
		if ( !self:Filter( ent, player ) ) then return end

		ent:Ignite( 360 )
	end
}








if SERVER then
	local flags = {}
	function nzu.GetMapFlagsList() return table.GetKeys(flags) end

	local ENTITY = FindMetaTable("Entity")

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
		end
		self.nzu_MapFlags[flag] = true
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

	-- Respond to net requests, but only in sandbox
	if NZU_SANDBOX then
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

	-- Properties for the serverside mirror
	-- But we override the Receive function
	property.Receive = function(self, length, player)
		local ent = net.ReadEntity()
		if !self:Filter(ent, player) then return end

		local num = net.ReadUInt(8)
		local tbl = {}
		for i = 1,num do
			table.insert(tbl, net.ReadString())
		end

		ent:SetMapFlags(tbl)
	end
	properties.Add("nzu_MapFlags", property)
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
		self.NewFlagButton = bottom:Add("DButton")
		self.NewFlagButton:SetText("Add new Flag")
		self.NewFlagButton:Dock(RIGHT)
		self.NewFlagButton:SetWide(50)
		self.NewFlagButton:DockMargin(5,0,0,0)

		self.NewFlagEntry = bottom:Add("DTextEntry")
		self.NewFlagEntry:SetPlaceholderText("Enter new flag ...")
		self.NewFlagEntry:Dock(FILL)

		local top = self:Add("Panel")
		top:Dock(TOP)
		top:SetTall(20)
		top:DockMargin(0,0,0,5)

		self.ControlHelp = top:Add("DLabel")
		self.ControlHelp:SetText("Use Shift/Ctrl to select multiple.")
		self.ControlHelp:Dock(FILL)

		self.RefreshButton = top:Add("DButton")
		self.RefreshButton:Dock(RIGHT)
		self.RefreshButton:SetWide(50)
		self.RefreshButton:SetText("Refresh")

		self.List = self:Add("DListView")
		self.List:SetMultiSelect(true)
		self.List:AddColumn("Flag")
		self.List:Dock(FILL)

		self:RefreshFlags()
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

	function PANEL:LoadFlags(tbl)
		local selectedflags = {}
		for k,v in pairs(self:GetSelectedFlags()) do
			selectedflags[v] = true
		end

		self.List:Clear()
		for k,v in pairs(tbl) do
			local p = self.List:AddLine(v)
			self.Flags[v] = selectedflags[v] or false
			if selectedflags[v] then
				p:SetSelected(true)
			end
		end

		self.ControlHelp:SetText("Use Shift/Ctrl to select multiple.")
		self.List:SetDisabled(self.m_bDisabled)
		self.NewFlagEntry:SetDisabled(self.m_bDisabled)
		self.NewFlagButton:SetDisabled(self.m_bDisabled)
		self.RefreshButton:SetDisabled(self.m_bDisabled)
	end

	function PANEL:AddNewFlag(str)
		for k,v in pairs(self.List:GetLines()) do
			if v:GetColumnText(1) == str then
				v:SetSelected(true)
				return
			end
		end

		self.List:AddLine(str):SetSelected(true)
	end

	function PANEL:GetSelectedFlags()
		local flags = {}
		for k,v in pairs(self.List:GetSelected()) do
			table.insert(flags, v:GetColumnText(1))
		end
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

	net.Receive("nzu_mapflags", function()
		local toreload
		if net.ReadBool() then
			local ent = net.ReadEntity()
			if IsValid(ent) then
				toreload = ent.nzu_MapFlagsPanelRefresh
				ent.nzu_MapFlagsPanelRefresh = nil
			end
		else
			toreload = torefresh
			torefresh = nil
		end

		if toreload then
			local num = net.ReadUInt(8)
			local tbl = {}
			for i = 1,num do
				table.insert(tbl, net.ReadString())
			end

			for k,v in pairs(toreload) do
				k:LoadFlags(tbl)
			end
		end
	end)
	vgui.Register("nzu_MapFlagsPanel", PANEL, "DPanel")

	-- A property that lets you modify the flags of a selected entity
	-- Works for any entity that has self.nzu_MapFlagsHandler field set
	-- (i.e. Entity:EnableMapFlags())

	property.Action = function(self, ent) -- Chance the clientside action to request a panel update
		local frame = vgui.Create("DFrame")
		frame:SetSize(200,400)
		frame:SetTitle("Edit Map Flags")
		frame:SetDeleteOnClose(true)
		frame:ShowCloseButton(false)
		frame:SetBackgroundBlur(true)
		frame:SetDrawOnTop(true)

		local l = frame:Add("nzu_MapFlagsPanel")
		l:Dock(FILL)
		l:ShowRefreshButton(false)
		l:RefreshFlags(ent)

		local save = frame:Add("DButton")
		save:Dock(BOTTOM)
		save:DockMargin(5,5,5,5)
		save:SetText("Apply")
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

		frame:Center()
		frame:MakePopup()
		frame:DoModal()
	end
	properties.Add("nzu_MapFlags", property)
end