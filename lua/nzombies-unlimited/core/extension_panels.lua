
--[[-------------------------------------------------------------------------
Generic Setting Type panel creation, for utility
---------------------------------------------------------------------------]]
function nzu.ExtensionSettingTypePanel(typ, parent, parent2)
	local build,toparent
	if parent2 then -- 3 arguments passed, meaning first is Extension ID, second is Setting Key, third is Parent
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
		local pnl = build:Panel(toparent)
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
	if p.nzu_NoNetwork then return end

	local val = v
	if val == nil then val = p:GetValue() end
	p.Extension:RequestChangeSetting(p.SettingKey, val)
end

local function setvaluenonetwork(p, v)
	p.nzu_NoNetwork = true
	p:SetValue(v)
	p.nzu_NoNetwork = nil
end

local PANEL = {}
function PANEL:AddSetting(key, tbl, parent)
	local tbl = tbl or self.Extension.Settings[key]
	local p = tbl:Panel(self)
	p:SetParent(parent or self)
	p.SettingKey = key
	p.Send = sendnetwork
	p.Extension = self.Extension
	p.SetValueNoNetwork = setvaluenonetwork
	self.Settings[key] = p

	p:SetValueNoNetwork(self.Extension[key])

	return p
end

function PANEL:Rebuild()
	local ext = self.Extension
	self:Clear()
	self.Settings = {} -- Reset key indexing

	-- If the extension comes with a BuildPanel function, we can run that on this panel to let the extension design its own layout
	if ext.BuildPanel then
		ext:BuildPanel(self)
	return end

	-- If the extension has no settings, let the player know
	if not ext.Settings then
		local l = self:Add("DLabel")
		l:SetText("This Extension has no settings.")
		l:Dock(TOP)
		l:SetContentAlignment(5)
	return end

	-- Default: Stack all settings in a vertical scroll panel. Order can be given with ZPos field. Label can be set with Label field.
	for k,v in pairs(ext.Settings) do
		local pnl = self:Add("Panel")
		pnl:SetZPos(v.ZPos or 0)

		local l = pnl:Add("DLabel")
		l:SetText(v.Label or k)
		--l:SetFont("ChatFont")
		l:Dock(TOP)

		local p = self:AddSetting(k,v, pnl)
		--p:SetParent(pnl)
		p:Dock(TOP)

		pnl:Dock(TOP)
		--pnl:SetTall(100)
		pnl:DockPadding(5,5,5,0)
		pnl:InvalidateLayout(true)
		pnl:SizeToChildren(false, true)
	end

	self:InvalidateLayout(true)
	self:SizeToChildren(false, true)
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

function PANEL:SetExtension(ext)
	self:Clear()
	if type(ext) == "string" then
		ext = nzu.GetExtension(ext)
	end

	self:OnRemove() -- This runs the removal of the panel from the extension's list of panels
	self.Extension = ext
	if not ext.Panels then ext.Panels = {} end
	ext.Panels[self] = true

	self:Rebuild()
end

function PANEL:OnRemove()
	if self.Extension and self.Extension.Panels[self] then
		self.Extension.Panels[self] = nil
		if table.IsEmpty(self.Extension.Panels) then self.Extension.Panels = nil end
	end
end

vgui.Register("nzu_ExtensionPanel", PANEL, "DPanel")