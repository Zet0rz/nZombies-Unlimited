
-- You can provide your own of this by setting the field CustomPanel to a table of this structure
local paneltypes = {
	[TYPE_STRING] = {
		Create = function(parent)
			local p = vgui.Create("DTextEntry", parent)
			p:SetTall(40)

			function p:OnFocusChanged(b)
				if not b then p:Send() end -- Trigger networking on text field focus lost
			end

			return p
		end,
		Set = function(p,v) p:SetText(v or "") end,
		Get = function(p) return p:GetText() end
	},
	[TYPE_NUMBER] = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)
			p.N = p:Add("DNumberWang")
			p.N:Dock(FILL)
			p.N:SetMinMax(nil,nil)
			p:SetTall(40)

			function p.N.OnValueChanged()
				if p.Send then p:Send() end -- Trigger networking whenever it changes
			end

			return p
		end,
		Set = function(p,v) p.N:SetValue(v) end,
		Get = function(p) return p.N:GetValue() end
	},
	[TYPE_BOOL] = {
		Create = function(parent)
			local p = vgui.Create("DCheckBoxLabel", parent)
			p:SetText("Enabled") p:SetTall(15)
			p:SetTextColor(color_black)

			function p:OnChange() p:Send() end -- Network when ticked

			return p
		end,
		Set = function(p,v) p:SetChecked(v) end,
		Get = function(p) return p:GetChecked() end
	},
	--[TYPE_ENTITY]		= function end,
	[TYPE_VECTOR] = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)

			p.S = p:Add("DButton")
			p.S:SetText("Save")
			p.S:Dock(RIGHT)
			p.S:SetWide(50)

			p.V = p:Add("DVectorEntry")
			p.V:Dock(FILL)

			p:SetSize(200,20)

			p.S.DoClick = function() p:Send() end -- Network on button click

			return p
		end,
		Set = function(p,v) p.V:SetVector(v) end,
		Get = function(p) return p.V:GetVector() end
	},
	[TYPE_ANGLE] = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)

			p.S = p:Add("DButton")
			p.S:SetText("Save")
			p.S:Dock(RIGHT)
			p.S:SetWide(50)

			p.A = p:Add("DAngleEntry")
			p.A:Dock(FILL)

			p:SetSize(200,20)

			p.S.DoClick = function() p:Send() end -- Network on button click

			return p
		end,
		Set = function(p,v) p.A:SetAngles(v) end,
		Get = function(p) return p.A:GetAngles() end
	},
	[TYPE_MATRIX] = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)

			p.S = p:Add("DButton")
			p.S:SetText("Save")
			p.S:Dock(BOTTOM)
			p.S:SetTall(20)

			p.M = p:Add("DMatrixEntry")
			p.M:Dock(FILL)

			p:SetSize(200,100)

			p.S.DoClick = function() p:Send() end -- Network on button click

			return p
		end,
		Set = function(p,v) p.M:SetMatrix(v) end,
		Get = function(p) return p.M:GetMatrix() end
	},
	[TYPE_COLOR] = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)

			p.S = p:Add("DButton")
			p.S:SetText("Save")
			p.S:Dock(BOTTOM)
			p.S:SetTall(20)

			p.C = p:Add("DColorMixer")
			p.C:Dock(FILL)

			p:SetSize(200,185)

			p.S.DoClick = function() p:Send() end -- Network on button click

			return p
		end,
		Set = function(p,v) p.C:SetColor(v) end,
		Get = function(p) local c = p.C:GetColor() return Color(c.r,c.g,c.b,c.a) end
	},
}

local function sendnetwork(p)
	nzu.RequestExtensionSetting(p._ExtensionID, p._ExtensionSetting, p:_GetValue())
end

local bext, bset, bsetpnl
local function nwpanel(id, parent)
	local setting = bset[id]
	if setting then
		local build = setting.CustomPanel or paneltypes[setting.Type]
		if build then
			local p = build.Create(parent, bext, id)
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