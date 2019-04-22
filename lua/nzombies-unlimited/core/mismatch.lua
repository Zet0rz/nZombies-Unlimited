local mismatches = nzu.Mismatches or {}
nzu.Mismatches = mismatches

function nzu.RegisterMismatch(key, tbl)
	if SERVER then
		tbl.BuildPanel = nil
		tbl.Icon = nil
	else
		tbl.Apply = nil
		tbl.Collect = nil
	end
	mismatches[key] = tbl
end

if SERVER then
	local function getadmins(ply)
		local t = {}
		for k,v in pairs(player.GetAll()) do
			if nzu.IsAdmin(v) or v == ply then
				table.insert(t, v)
			end
		end
		return t
	end

	-- Instant mismatch invoked through code
	util.AddNetworkString("nzu_mismatch")
	util.AddNetworkString("nzu_mismatch_available")
	function nzu.CollectMismatch(cat)
		local tbl = mismatches[cat]
		if tbl then
			return tbl.Collect()
		end
	end
	
	function nzu.GetMismatchers() return mismatches end
	
	local found = {}
	function nzu.GetAvailableMismatches() return found end

	-- Network availability
	local function networkavailability(key, b, ply)
		net.Start("nzu_mismatch_available")
			net.WriteString(key)
			net.WriteBool(b)
		net.Send(IsValid(ply) and ply or getadmins())
	end

	local function networkmismatch(key, data, ply)
		net.Start("nzu_mismatch")
			net.WriteString(key)
			mismatches[key].Write(data)
		net.Send(IsValid(ply) and ply or getadmins())
	end
	
	function nzu.Mismatch(cat, ply)
		if not cat then
			for k,v in pairs(mismatches) do
				nzu.Mismatch(k, ply)
			end
		return end
		
		local data = nzu.CollectMismatch(cat)
		if data then
			found[cat] = data
			networkavailability(cat, true, ply)
			hook.Run("nzu_MismatchFound", cat, data)
		else
			if found[cat] then networkavailability(cat, false, ply) end
			found[cat] = nil
		end
	end

	net.Receive("nzu_mismatch_available", function(len, ply)
		if not nzu.IsAdmin(ply) then return end
		
		if net.ReadBool() then
			local t = net.ReadString()
			if mismatches[t] and found[t] then
				networkmismatch(t, found[t], ply)
			else
				networkavailability(t, false, ply) -- Tell the player it's no longer available
			end
		elseif nzu.IsAdmin(ply) then
			nzu.Mismatch()
		end
	end)
	
	net.Receive("nzu_mismatch", function(len, ply)
		if not nzu.IsAdmin(ply) then return end
		
		local t = net.ReadString()
		if mismatches[t] and found[t] then
			local data = mismatches[t].Read()
			if data then
				mismatches[t].Apply(data)
				networkavailability(t, false)
				found[t] = nil
				hook.Run("nzu_MismatchFixed", t, data)
			end
		end
	end)
	
	-- Loading mismatch data on config load, queueing the data for any admin to receive on join
	hook.Add("nzu_PostConfigMap", "nzu_Mismatch_Check", function() nzu.Mismatch() end)
	hook.Add("PlayerInitialSpawn", "nzu_Mismatch_AdminJoin", function(ply)
		if nzu.IsAdmin(ply) then
			for k,v in pairs(found) do
				networkavailability(k, true, ply)
			end
		end
	end)
end

if SERVER then return end
-- Below here is the client PANEL setup

local availablemismatch = {}
local mismatchdata = {}
net.Receive("nzu_mismatch_available", function()
	local key = net.ReadString()	
	mismatchdata[key] = nil -- Always wipe the data when receiving availability: Either it's new data available, or it's no data available

	if net.ReadBool() then
		availablemismatch[key] = true
		hook.Run("nzu_MismatchFound", key)
	elseif availablemismatch[key] then
		availablemismatch[key] = nil
		hook.Run("nzu_MismatchFixed", key)
	end
end)

net.Receive("nzu_mismatch", function()
	local key = net.ReadString()
	local m = mismatches[key]
	if not m then return end

	local data = m.Read()
	if not availablemismatch[key] then
		availablemismatch[key] = true
		hook.Run("nzu_MismatchFound", key)
	end

	mismatchdata[key] = data
	hook.Run("nzu_MismatchData", key, data)
end)

function nzu.GetAvailableMismatches() return table.GetKeys(availablemismatch) end
function nzu.GetReceivedMismatchData(cat) return mismatchdata[cat] end
function nzu.MismatchAvailable() return next(availablemismatch) ~= nil end

-- Request data if it's available, and we're admins of course
function nzu.RequestMismatchData(cat)
	if nzu.IsAdmin(LocalPlayer()) then
		local function dorequest(cat)
			if availablemismatch[cat] and not mismatchdata[cat] then
				net.Start("nzu_mismatch_available")
					net.WriteBool(true)
					net.WriteString(cat)
				net.SendToServer()
			end
		end

		if cat then
			dorequest(cat)
		else
			for k,v in pairs(availablemismatch) do
				dorequest(k)
			end
		end
	end
end

-- Requests a re-check
function nzu.RequestMismatch()
	if nzu.IsAdmin(LocalPlayer()) then
		net.Start("nzu_mismatch_available")
			net.WriteBool(false)
		net.SendToServer()
	end
end

--[[-------------------------------------------------------------------------
Auto-networking panel
---------------------------------------------------------------------------]]

local PANEL = {}
function PANEL:Init()
	self.Sheet = self:Add("DPropertySheet")
	self.Sheet:Dock(FILL)
	
	self.Save = self:Add("DButton")
	self.Save:Dock(BOTTOM)
	self.Save:DockMargin(5,5,5,5)
	self.Save:SetText("Apply")
	
	self.Items = {}
	
	self.Save.DoClick = function(s)
		local tab = self.Sheet:GetActiveTab()
		if IsValid(tab) and tab.Mismatch and mismatches[tab.Mismatch] then
			local pnl = tab:GetPanel()
			if IsValid(pnl) and pnl.GetMismatch then
				net.Start("nzu_mismatch")
					net.WriteString(tab.Mismatch)
					mismatches[tab.Mismatch].Write(pnl:GetMismatch())
				net.SendToServer()
			end
		end
	end
	
	for k,v in pairs(nzu.GetAvailableMismatches()) do
		self:AddMismatch(v,nzu.GetReceivedMismatchData(v))
	end
	
	hook.Add("nzu_MismatchFound", self, self.AddMismatch) -- Adds the tab without the data
	hook.Add("nzu_MismatchData", self, self.AddMismatch)
	hook.Add("nzu_MismatchFixed", self, self.CloseMismatch)
end

function PANEL:AddDefaultTab()
	if not IsValid(self.DefaultTab) then
		local pnl = vgui.Create("DLabel", self.Sheet)
		pnl:SetText("No Mismatches found.")
		pnl:SetContentAlignment(8)

		local tbl = self.Sheet:AddSheet("No Mismatches", pnl)
		self.DefaultTab = tbl.Tab
	end
end

function PANEL:AddMismatch(key, data)
	if mismatches[key] then

		-- Remove and rebuild if we get an "update"
		if self.Items[key] then
			if #self.Items <= 1 then self:AddDefaultTab() end
			self.Sheet:CloseTab(self.Items[key].Tab, true)
		end
		
		local pnl
		if data then
			pnl = mismatches[key].BuildPanel(self.Sheet, data)
			if not pnl then
				ErrorNoHalt("Mismatch added with no panel returned by BuildPanel! ["..key.."]")
				debug.Trace()
			return end
			
			-- If the returned thing is a table, a ListLayout is created with each entry in order
			-- If an entry is a panel, this panel is added to the layout
			-- If an entry is a table, and the first value being a string corresponding to an Extension Setting Type
			-- and the second value a piece of data, this panel type is created and set to this data in the ListLayout

			-- The data gathered by this list is the same ordered table, with GetMismatch called on each of them as the value
			-- For all Extension Setting Type panels, this is the Get value of the Panel
			if type(pnl) == "table" then
				local p = vgui.Create("DListLayout", self.Sheet)
				p.Keys = {}
				for k,v in pairs(pnl) do
					local d
					if type(v) == "Panel" then
						d = v
					else
						local build = v[1] and nzu.GetExtensionSettingType(v[1])
						if build and build.Panel then
							d = build.Panel.Create(p)
							build.Panel.Set(d, v[2])
							d.GetMismatch = build.Panel.Get
							d.Send = function() end -- So it won't error
						end
					end
					if IsValid(d) then
						d:Dock(TOP)
						p:Add(d)
						p.Keys[k] = d
					end
				end

				p.GetMismatch = function(s)
					local t = {}
					for k,v in pairs(s.Keys) do
						t[k] = v:GetMismatch()
					end
					return t
				end
				
				pnl = p
			end
		else
			pnl = vgui.Create("DLabel", self.Sheet)
			pnl:SetText("Mismatch data not yet received.")
			pnl:SetContentAlignment(8)
		end
	
		local tbl = self.Sheet:AddSheet(key, pnl, mismatches[key].Icon)
		pnl:Dock(FILL)
		pnl:DockMargin(5,5,5,5)
		tbl.Tab.Mismatch = key
		self.Items[key] = tbl

		if IsValid(self.DefaultTab) then
			self.Sheet:CloseTab(self.DefaultTab, true)
			self.DefaultTab = nil
		end

		self:OnMismatchAdded(key, data, tbl)
	end
end

function PANEL:CloseMismatch(key)
	if IsValid(self.Items[key].Tab) then
		if #self.Items <= 1 then self:AddDefaultTab() end

		self.Sheet:CloseTab(self.Items[key].Tab, true)
		self:OnMismatchClosed(key)
	end
end

-- For override
function PANEL:OnMismatchClosed() end
function PANEL:OnMismatchAdded() end

vgui.Register("nzu_MismatchPanel", PANEL, "DPanel")