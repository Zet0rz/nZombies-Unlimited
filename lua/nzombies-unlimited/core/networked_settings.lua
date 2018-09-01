local SETTINGS = {}
SETTINGS.__index = SETTINGS
debug.getregistry().nzu_NetworkedSettings = SETTINGS

local writetypes = {
	[TYPE_STRING]		= function ( v )	net.WriteString( v )		end,
	[TYPE_NUMBER]		= function ( v )	net.WriteDouble( v )		end,
	[TYPE_TABLE]		= function ( v )	net.WriteTable( v )			end,
	[TYPE_BOOL]			= function ( v )	net.WriteBool( v )			end,
	[TYPE_ENTITY]		= function ( v )	net.WriteEntity( v )		end,
	[TYPE_VECTOR]		= function ( v )	net.WriteVector( v )		end,
	[TYPE_ANGLE]		= function ( v )	net.WriteAngle( v )			end,
	[TYPE_MATRIX]		= function ( v )	net.WriteMatrix( v )		end,
	[TYPE_COLOR]		= function ( v )	net.WriteColor( v )			end,
}

function SETTINGS:NetWriteSetting(setting, val)
	local settingtbl = self[setting]
	net.WriteString(setting)
	if settingtbl.NetSend then
		settingtbl.NetSend(self, val)
	elseif settingtbl.Type then
		writetypes[settingtbl.Type](val)
	end
end

function SETTINGS:NetReadSetting()
	local setting = net.ReadString()
	local settingtbl = self[setting]
	if settingtbl.NetRead then
		val = settingtbl.NetRead(self)
	elseif settingtbl.Type then
		val = net.ReadVars[settingtbl.Type]()
	end

	return setting, val
end

if CLIENT then
	local pnl = {}
	function pnl:SetSettings(u)
		
		
		if not IsValid(self.TopPanel) then
			self.TopPanel = self:Add("Panel")
			self.TopPanel:Dock(TOP)
			self.TopPanel:SetTall(30)
		end

		if not IsValid(self.SaveAll) then
			self.SaveAll = self.TopPanel:Add("DButton")
			self.SaveAll:Dock(RIGHT)
			self.SaveAll:SetWide(60)
			self.SaveAll:SetText("Save all")
			self.SaveAll:DockMargin(5,5,5,5)
			self.SaveAll.DoClick = function(s)
				for k,v in pairs(self.Settings) do v._Save() end
			end
		end

		if not IsValid(self.ReloadAll) then
			self.ReloadAll = self.TopPanel:Add("DButton")
			self.ReloadAll:Dock(RIGHT)
			self.ReloadAll:SetWide(60)
			self.ReloadAll:SetText("Reload All")
			self.ReloadAll:DockMargin(5,5,0,5)
			self.ReloadAll.DoClick = function(s)
				self:Reload()
			end
		end

		if not IsValid(self.Name) then
			self.Name = self.TopPanel:Add("DLabel")
			self.Name:Dock(TOP)
			self.Name:SetContentAlignment(4)
			self.Name:SetTextColor(color_black)
			self.Name:SetTextInset(5,0)
		end
		self.Name:SetText(u.Name or "[No Name]")
		self.Name:SizeToContents()

		if not IsValid(self.Class) then
			self.Class = self.TopPanel:Add("DLabel")
			self.Class:SetContentAlignment(4)
			self.Class:Dock(TOP)
			self.Class:SetTextColor(color_black)
			self.Class:SetTextInset(5,0)
		end
		self.Class:SetText(tostring(u))
		self.Class:SizeToContents()
		
		if not IsValid(self.Categories) then
			self.Categories = self:Add("DCategoryList")
			self.Categories:Dock(FILL)
		else
			self.Categories:Clear()
		end

		self.Settings = {}
		for k,v in pairs(u.Settings) do
			local panel
			if v.CustomPanel then
				panel = v.CustomPanel.Create()
				v.CustomPanel.Set(panel, u:GetLogicSetting(k))
				panel._GetValue = v.CustomPanel.Get
				panel._SetValue = v.CustomPanel.Set
			elseif v.Type and createpanel[v.Type] then
				panel = createpanel[v.Type]()
				setvalue[v.Type](panel, u:GetLogicSetting(k))
				panel._GetValue = getvalue[v.Type]
				panel._SetValue = setvalue[v.Type]
			end

			if panel then
				panel._Save = function()
					net.Start("nzu_logicmap_setting")
						net.WriteUInt(u:LogicIndex(), 16)
						u:NetWriteLogicSetting(k, panel:_GetValue())
					net.SendToServer()
				end

				local cat = self.Categories:Add(k)
				cat:SetTall(panel:GetTall())
				cat:SetExpanded(true)
				cat:SetContents(panel)
				cat:DockMargin(0,0,0,1)

				local save = cat.Header:Add("DButton")
				save:Dock(RIGHT)
				save:DockMargin(2,2,2,2)
				save:SetWide(50)
				save:SetText("Save")
				save.DoClick = panel._Save

				self.Settings[k] = panel
			end
		end

		self.m_lUnit = u
	end

	function pnl:Reload()
		if not self.Settings or not IsValid(self.m_lUnit) then return end
		for k,v in pairs(self.Settings) do
			v:_SetValue(self.m_lUnit:GetLogicSetting(k))
		end
	end
	derma.DefineControl("DNetworkedSettingsPanel", "", pnl, "DPanel")

	function SETTINGS:CreatePanel()

	end
end