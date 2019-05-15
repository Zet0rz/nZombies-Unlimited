
--[[-------------------------------------------------------------------------
Generic Setting Type panel creation, for utility
---------------------------------------------------------------------------]]
function nzu.ExtensionSettingTypePanel(typ, parent, parent2)
	local build,toparent
	if parent2 then -- 3 arguments passed, meaning first is Extension ID, second is Setting Key, third is Paren
		local ext = nzu.GetExtension(typ)
		if ext then
			local m = ext.GetSettingsMeta()
			if m and m[parent] then
				build = m[parent]
			end
		end
		toparent = parent2
	else
		build = typ and nzu.GetExtensionSettingType(typ)
		toparent = parent
	end

	if build and build.Panel then
		local pnl = build.Panel(toparent)
		if IsValid(pnl) then
			pnl.Send = function() end -- You can override this after receiving the panel if you want
			return pnl
		end
	end
end


--[[-------------------------------------------------------------------------
Networked Extension Panel
---------------------------------------------------------------------------]]
local function sendnetwork(p, v)
	local val = v
	if val == nil then val = p:GetValue() end
	nzu.RequestExtensionSetting(p._ExtensionID, p._ExtensionSetting, val)
end

local bext, bset, bsetpnl
local function nwpanel(id, parent)
	local setting = bset[id]
	if setting then
		local build = setting.Panel
		if build then
			local p = build(parent, bext, id, setting)
			p.SetValue(p, bext.Settings[id])
			p._ExtensionID = bext.ID
			p._ExtensionSetting = id

			p.Send = sendnetwork -- This is called to send its information to the server

			bsetpnl[id] = p
			return p
		end
	end
end

local PANEL = {}
function PANEL:_HookUpdate(setting, value)
	if self.SettingPanels[setting] then
		self.SettingPanels[setting]:SetValue(value)
	end
end

local extpanels = {}
function PANEL:Rebuild()
	local ext = self.Extension
	self:Clear()

	local pf = ext.GetPanelFunction()
	if not pf then
		local l = self:Add("DLabel")
		l:SetText("This Extension has no settings.")
		l:Dock(TOP)
		l:SetContentAlignment(5)
	return end

	-- Build the panel
	bext = ext
	bset = ext.GetSettingsMeta()
	bsetpnl = {}
	local tall = pf(self, nwpanel)
	self.SettingPanels = bsetpnl -- Store this so hooks can access them by ID
	bext = nil
	bset = nil
	bsetpnl = nil

	if tall then self:SetTall(tall) else self:SizeToChildren(false, true) end

	self:Highlight()
end

function PANEL:Highlight()
	self.HighlightVal = 255
end

local highlightdecay = 255
function PANEL:PaintOver(w,h)
	if self.HighlightVal then
		self.HighlightVal = self.HighlightVal - FrameTime()*highlightdecay
		surface.SetDrawColor(0,255,0,self.HighlightVal)
		self:DrawFilledRect()

		if self.HighlightVal <= 0 then self.HighlightVal = nil end
	end
end

local function dorebuilds(ext)
	local id = ext.ID
	if extpanels[id] then
		for k,v in pairs(extpanels[id]) do
			if IsValid(k) then
				k:Rebuild()
			else
				extpanels[k] = nil
			end
		end
	end
end

hook.Add("nzu_ExtensionSettingChanged", "nzu_ExtensionPanels_NetworkUpdate", function(name, setting, value)
	if extpanels[name] then
		for k,v in pairs(extpanels[name]) do
			if IsValid(k) then
				k:_HookUpdate(setting, value)
			else
				extpanels[k] = nil
			end
		end
	end
end)

function PANEL:SetExtension(ext)
	self:Clear()
	if type(ext) == "string" then
		ext = nzu.GetExtension(ext)
	end

	self.Extension = ext
	local id = ext.ID
	if ext then
		self:Rebuild()
		if not extpanels[id] then extpanels[id] = {} end
		extpanels[id][self] = true
		ext.RebuildPanels = dorebuilds
	else
		if extpanels[id] then
			extpanels[id][self]  = nil
			if table.IsEmpty(extpanels[id]) then extpanels[id] = nil end
		end
	end

	self:InvalidateLayout(true)
	self:SizeToChildren(true, true)
end

vgui.Register("nzu_ExtensionPanel", PANEL, "DPanel")