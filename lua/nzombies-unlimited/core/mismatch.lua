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
	function nzu.CollectMismatch(cat)
		local tbl = mismatches[cat]
		if tbl then
			return tbl.Collect()
		end
	end
	
	function nzu.GetMismatchers() return mismatches end
	
	local found = {}
	function nzu.GetAvailableMismatches() return found end
	local function networkmismatch(key, data, ply)
		net.Start("nzu_mismatch")
			net.WriteString(key)
			net.WriteBool(true)
			mismatches[key].Write(data)
		net.Send(IsValid(ply) and ply or getadmins())
	end
	
	function nzu.Mismatch(cat, ply)
		if not cat then
			found = {}
			for k,v in pairs(mismatches) do
				nzu.Mismatch(k, ply)
			end
		return end
		
		local tbl = mismatches[cat]
		if tbl then
			local data = tbl.Collect()
			if data then
				networkmismatch(cat, data, ply)
				found[cat] = data
				hook.Run("nzu_MismatchFound", cat, data)
			else
				found[cat] = nil
			end
		end
	end
	
	net.Receive("nzu_mismatch", function(len, ply)
		if not nzu.IsAdmin(ply) then return end
		
		local t = net.ReadString()
		if mismatches[t] then
			local data = mismatches[t].Read()
			if data then
				if mismatches[t].Apply(data) then
					net.Start("nzu_mismatch")
						net.WriteString(t)
						net.WriteBool(false)
					net.Send(getadmins())
					found[t] = nil
					hook.Run("nzu_MismatchFixed", t)
				else
					-- Not fixed, re-send remaining data
					local data = mismatches[t].Collect()
					networkmismatch(t, data)
					found[t] = data
					hook.Run("nzu_MismatchFound", t, data)
				end
			end
		end
	end)
	
	-- Loading mismatch data on config load, queueing the data for any admin to receive on join
	hook.Add("nzu_PostConfigMap", "nzu_Mismatch_Check", function() nzu.Mismatch() end)
	hook.Add("PlayerInitialSpawn", "nzu_Mismatch_AdminJoin", function(ply)
		if nzu.IsAdmin(ply) then
			for k,v in pairs(found) do
				networkmismatch(k, v, ply)
			end
		end
	end)
end

if SERVER then return end
-- Below here is the client PANEL setup

local availablemismatch = {}
net.Receive("nzu_mismatch", function()
	local key = net.ReadString()
	local m = mismatches[key]
	if not m then return end
	
	if net.ReadBool() then
		local data = m.Read()
		availablemismatch[key] = data
		hook.Run("nzu_MismatchFound", key, data)
	elseif availablemismatch[key] then
		availablemismatch[key] = nil
		hook.Run("nzu_MismatchFixed", key)
	end
end)
function nzu.GetAvailableMismatches() return availablemismatch end
hook.Add("nzu_ConfigLoaded", "nzu_Mismatch_ResetList", function() availablemismatch = {} end)

local PANEL = {}
function PANEL:Init()
	self.Sheet = self:Add("DPropertySheet")
	self.Sheet:Dock(FILL)
	
	self.Save = self:Add("DButton")
	self.Save:Dock(BOTTOM)
	self.Save:DockMargin(5,5,5,5)
	self.Save:SetText("Apply")
	
	self.Tabs = {}
	
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
		self:AddMismatch(k,v)
	end
	
	hook.Add("nzu_MismatchFound", self, self.AddMismatch)
	hook.Add("nzu_MismatchFixed", self, self.CloseMismatch)
end

function PANEL:AddMismatch(key, data)
	if mismatches[key] then
		self:CloseMismatch(key) -- Remove and rebuild if we get an "update"
		
		local pnl = mismatches[key].BuildPanel(self.Sheet, data)
		
		-- If the returned thing is a table of Extension Setting types with keys for each setting
		-- Then create those panels and set them with the value of the data for that key
		-- And the GetMismatch() function returns the same table keys, but with the panels' new values
		if type(pnl) == "table" then
			local p = vgui.Create("DListLayout", self.Sheet)
			p.Keys = {}
			for k,v in pairs(pnl) do
				if data[k] then
					local build = nzu.GetExtensionSettingType(v)
					if build and build.Panel then
						local d = build.Panel.Create(p)
						build.Panel.Set(d, data[k])
						d._GetValue = build.Panel.Get
						
						p.Keys[k] = d
						p:Add(d)
						d:Dock(TOP)
					end
				end
			end
			p.GetMismatch = function(s)
				local t = {}
				for k,v in pairs(s.Keys) do
					t[k] = v:_GetValue()
				end
				return t
			end
			
			pnl = p
		end
	
		local tbl = self.Sheet:AddSheet(key, pnl, mismatches[key].Icon)
		pnl:Dock(FILL)
		tbl.Tab.Mismatch = key
		self.Tabs[key] = tbl.Tab
	end
end

function PANEL:CloseMismatch(key)
	if IsValid(self.Tabs[key]) then
		self.Sheet:CloseTab(self.Tabs[key], true)
	end
end

vgui.Register("nzu_MismatchPanel", PANEL, "DPanel")