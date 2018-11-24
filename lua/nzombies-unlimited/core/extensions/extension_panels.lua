
-- You can provide your own of this by setting the field CustomPanel to a table of this structure
local paneltypes = {
	[TYPE_STRING] = {
		Create = function()
			local p = vgui.Create("DTextEntry")
			p:SetTall(40)

			function p:OnFocusChanged(b)
				print(b)
				if not b then p:Send() end -- Trigger networking on text field focus lost
			end

			return p
		end,
		Set = function(p,v) p:SetText(v or "") end,
		Get = function(p) return p:GetText() end
	},
	[TYPE_NUMBER] = {
		Create = function()
			local p = vgui.Create("Panel")
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
		Create = function()
			local p = vgui.Create("DCheckBoxLabel")
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
		Create = function()
			local p = vgui.Create("Panel")

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
		Create = function()
			local p = vgui.Create("Panel")

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
		Create = function()
			local p = vgui.Create("Panel")

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
		Create = function()
			local p = vgui.Create("Panel")

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
local function nwpanel(id)
	local setting = bset[id]
	if setting then
		local build = setting.CustomPanel or paneltypes[setting.Type]
		if build then
			local p = build.Create()
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

function nzu.GetExtensionPanel(ext)
	local extension = nzu.GetExtensionPanelFunction(ext)
	if not extension then return end
	
	-- Set SettingPanel global function only for this
	local oldval = SettingPanel
	SettingPanel = nwpanel

	-- Build the panel
	bext = nzu.GetExtension(ext)
	bset = nzu.GetExtensionSettings(ext)
	bsetpnl = {}
	local panel = extension()
	panel.SettingPanels = bsetpnl -- Store this so hooks can access them by ID
	bext = nil
	bset = nil
	bsetpnl = nil

	-- Reset old values and return the panel
	SettingPanel = oldval
	return panel
end