
--[[-------------------------------------------------------------------------
Generic Setting Type panel creation, for utility
---------------------------------------------------------------------------]]
function nzu.ExtensionSettingTypePanel(typ, parent)
	local build = typ and nzu.GetExtensionSettingType(typ)
	if build and build.Panel then
		local pnl = build.Panel.Create(parent)
		if IsValid(pnl) then
			pnl.Set = build.Panel.Set
			pnl.Get = build.Panel.Get
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
	if val == nil then val = p:_GetValue() end
	nzu.RequestExtensionSetting(p._ExtensionID, p._ExtensionSetting, val)
end

local bext, bset, bsetpnl
local function nwpanel(id, parent)
	local setting = bset[id]
	if setting then
		local build = setting.Panel
		if build then
			local p = build.Create(parent, bext, id, setting)
			p._SetValue = build.Set
			p._GetValue = build.Get

			p._SetValue(p, bext.Settings[id])
			p._ExtensionID = bext.ID
			p._ExtensionSetting = id

			p.Send = sendnetwork -- This is called to send its information to the server

			bsetpnl[id] = p
			return p
		end
	end
end

local PANEL = {}
function PANEL:_HookUpdate(ext, setting, value)
	if ext == self.Extension then
		if self.SettingPanels[setting] then self.SettingPanels[setting]:_SetValue(value) end
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
	pf(self, nwpanel)
	self.SettingPanels = bsetpnl -- Store this so hooks can access them by ID
	bext = nil
	bset = nil
	bsetpnl = nil

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
	if extpanels[ext] then
		for k,v in pairs(extpanels[ext]) do
			if IsValid(k) then
				k:Rebuild()
			else
				extpanels[k] = nil
			end
		end
	end
end

function PANEL:SetExtension(ext)
	self:Clear()
	if type(ext) == "string" then
		ext = nzu.GetExtension(ext)
	end

	self.Extension = ext
	if ext then
		self:Rebuild()
		if not extpanels[ext] then extpanels[ext] = {} end
		extpanels[ext][self] = true

		ext.RebuildPanels = dorebuilds
		hook.Add("nzu_ExtensionSettingChanged", self, self._HookUpdate)
	else
		if extpanels[ext] then extpanels[ext][self]  = nil end
		hook.Remove("nzu_ExtensionSettingChanged", self)
	end

	self:InvalidateLayout(true)
	self:SizeToChildren(true, true)
end

vgui.Register("nzu_ExtensionPanel", PANEL, "DPanel")