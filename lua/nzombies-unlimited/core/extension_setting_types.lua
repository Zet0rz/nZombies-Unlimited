
-- String: A text entry that will send whenever it loses focus
nzu.AddExtensionSettingType("String", {
	NetRead = net.ReadString,
	NetWrite = net.WriteString,
	Panel = function(parent)
		local p = vgui.Create("DTextEntry", parent)
		p:SetTall(40)

		function p:OnFocusChanged(b)
			if not b then self:Send() end -- Trigger networking on text field focus lost
		end
		function p:GetValue() return self:GetText() end

		return p
	end
})

-- Number: A networked double with a Number Wang
nzu.AddExtensionSettingType("Number", {
	NetRead = net.ReadDouble,
	NetWrite = net.WriteDouble,
	Panel = function(parent)
		local p = vgui.Create("Panel", parent)
		p.N = p:Add("DNumberWang")
		p.N:Dock(FILL)
		p.N:SetMinMax(nil,nil)
		p:SetTall(40)

		function p.N.OnValueChanged()
			if p.Send then p:Send() end -- Trigger networking whenever it changes
		end

		function p:SetValue(n) self.N:SetValue(n) end
		function p:GetValue() return self.N:GetValue() end

		return p
	end
})

-- Boolean: A true/false value that appears as a checkbox, networked whenever clicked
nzu.AddExtensionSettingType("Boolean", {
	NetRead = net.ReadBool,
	NetWrite = net.WriteBool,
	Panel = function(parent)
		local p = vgui.Create("DCheckBoxLabel", parent)
		p:SetText("Enabled")
		p:SetTall(15)
		p:SetTextColor(color_black)

		function p:OnChange(b) self:Send() end
		function p:SetValue(v) self:SetChecked(v) end
		function p:GetValue() return self:GetChecked() end

		return p
	end
})

-- Vector: 3 number wangs with an associated Save button. Uses DVectorEntry (included in nZU)
nzu.AddExtensionSettingType("Vector", {
	NetRead = net.ReadVector,
	NetWrite = net.WriteVector,
	Panel = function(parent)
		local p = vgui.Create("Panel", parent)

		p.S = p:Add("DButton")
		p.S:SetText("Save")
		p.S:Dock(RIGHT)
		p.S:SetWide(50)

		p.V = p:Add("DVectorEntry")
		p.V:Dock(FILL)

		p:SetSize(200,20)

		p.S.DoClick = function() p:Send() end -- Network on button click
		function p:SetValue(v) self.V:SetVector(v) end
		function p:GetValue() return self.V:GetVector() end

		return p
	end
})

-- Angle: 3 number wangs with an associated Save button, similar to Vector
nzu.AddExtensionSettingType("Angle", {
	NetRead = net.ReadAngle,
	NetWrite = net.WriteAngle,
	Panel = function(parent)
		local p = vgui.Create("Panel", parent)

		p.S = p:Add("DButton")
		p.S:SetText("Save")
		p.S:Dock(RIGHT)
		p.S:SetWide(50)

		p.A = p:Add("DAngleEntry")
		p.A:Dock(FILL)

		p:SetSize(200,20)

		p.S.DoClick = function() p:Send() end -- Network on button click
		function p:SetValue(v) self.A:SetAngles(v) end
		function p:GetValue() return self.A:GetAngles() end

		return p
	end
})

-- Matrix: 4x4 number wangs with an associated Save button, also similar to Angle and Vector
nzu.AddExtensionSettingType("Matrix", {
	NetRead = net.ReadMatrix,
	NetWrite = net.WriteMatrix,
	Panel = function(parent)
		local p = vgui.Create("Panel", parent)

		p.S = p:Add("DButton")
		p.S:SetText("Save")
		p.S:Dock(BOTTOM)
		p.S:SetTall(20)

		p.M = p:Add("DMatrixEntry")
		p.M:Dock(FILL)

		p:SetSize(200,100)

		p.S.DoClick = function() p:Send() end -- Network on button click

		function p:SetValue(v) self.M:SetMatrix(v) end
		function p:GetValue() return self.M:GetMatrix() end

		return p
	end
})

-- Color: A color select with a Save button
nzu.AddExtensionSettingType("Color", {
	NetRead = net.ReadColor,
	NetWrite = net.WriteColor,
	Load = function(t) return IsColor(t) and t or Color(t.r, t.g, t.b, t.a) end,
	Panel = function(parent)
		local p = vgui.Create("Panel", parent)

		p.S = p:Add("DButton")
		p.S:SetText("Save")
		p.S:Dock(BOTTOM)
		p.S:SetTall(20)

		p.C = p:Add("DColorMixer")
		p.C:Dock(FILL)

		p:SetSize(200,185)

		p.S.DoClick = function() p:Send() end -- Network on button click

		function p:SetValue(v) self.C:SetColor(v) end
		function p:GetValue() local c = self.C:GetColor() return Color(c.r,c.g,c.b,c.a) end

		return p
	end
})

-- Weapon: A text field dropdown that contains all installed weapons, including a search field to filter the dropdown
nzu.AddExtensionSettingType("Weapon", {
	NetWrite = net.WriteString,
	NetRead = net.ReadString,
	Panel = function(parent, ext, setting)
		local p = vgui.Create("DSearchComboBox", parent)

		p:AddChoice("  [None]", "") -- Allow the choice of none
		for k,v in pairs(weapons.GetList()) do
			p:AddChoice((v.PrintName or "").." ["..v.ClassName.."]", v.ClassName)
		end
		p:SetAllowCustomInput(true)

		function p:OnSelect(index, value, data)
			self:Send()
		end

		function p:SetValue(v)
			for k,class in pairs(self.Data) do
				if class == v then
					self:SetText(self:GetOptionText(k))
					self.selected = k
					return
				end
			end

			self.Choices[0] = v
			self.Data[0] = v
			self.selected = 0
			self:SetText(v)
		end

		function p:GetValue()
			local str,data = self:GetSelected()
			return data
		end

		return p
	end
})

-- Weighted Weapon List: A list of weapons where each weapon has a weight associated to it. Its internal value is a table where each weapon class is the key,
-- and the associated weight is the value. This is used for example in the Mystery Box weapons list.
nzu.AddExtensionSettingType("WeightedWeaponList", {
	Default = {}, -- Default is empty = use all installed weapons (that are valid)
	NetRead = function()
		local t = {}
		local num = net.ReadUInt(16)
		for i = 1,num do
			local class = net.ReadString()
			t[class] = net.ReadUInt(16)
		end
		return t
	end,
	NetWrite = function(t)
		local t2 = table.GetKeys(t)
		local num = #t2
		net.WriteUInt(num, 16)
		for i = 1,num do
			local class = t2[i]
			net.WriteString(class)
			net.WriteUInt(t[class], 16)
		end
	end,
	Panel = function(parent, ext)
		local p = parent:Add("Panel")
		p:SetTall(350)
		p:DockMargin(10,10,10,10)

		local l = p:Add("DListView")
		l:Dock(FILL)
		l:AddColumn("Weapon Class")
		l:AddColumn("Weapon Name")
		l:AddColumn("Weight")
		l:SetMultiSelect(true)
		l:DockMargin(0,0,0,5)

		local save = p:Add("DButton")
		save:SetText("Apply Changes")
		save:Dock(BOTTOM)
		save:SetTall(20)
		save:DockMargin(10,10,10,10)
		function save:DoClick()
			p:Send()
		end

		local add = p:Add("Panel")
		add:Dock(BOTTOM)
		add:SetTall(20)

		local entry = add:Add("DSearchComboBox")
		for k,v in pairs(weapons.GetList()) do
			entry:AddChoice((v.PrintName or "").." ["..v.ClassName.."]", v.ClassName)
		end
		entry:SetAllowCustomInput(true)
		entry:Dock(FILL)

		local plus = add:Add("DImageButton")
		plus:Dock(RIGHT)
		plus:SetWide(16)
		plus:SetImage("icon16/add.png")
		plus:DockMargin(5,2,0,2)

		local num = add:Add("DNumberWang")
		num:SetDecimals(0)
		num:SetMin(1)
		num:SetValue(100)
		num:SetWide(75)
		num:Dock(RIGHT)
		num:DockMargin(5,0,0,0)

		local selected = p:Add("Panel")
		selected:Dock(BOTTOM)
		selected:SetTall(20)
		selected:DockMargin(0,0,0,10)

		local lbl = selected:Add("DLabel")
		lbl:Dock(FILL)
		lbl:SetText("0 Selected")

		local ur = selected:Add("DButton")
		ur:SetText("Remove")
		ur:SetDisabled(true)
		ur:SetWide(150)
		ur:Dock(RIGHT)
		ur:DockMargin(5,0,0,0)
		function ur:DoClick()
			for k,v in pairs(l:GetLines()) do
				if v:IsLineSelected() then
					l:RemoveLine(k)
				end
			end
			l:OnRowSelected() -- Just to refresh
		end

		local uw = selected:Add("DButton")
		uw:SetText("Update Weights")
		uw:SetDisabled(true)
		uw:SetWide(150)
		uw:Dock(RIGHT)
		uw:DockMargin(5,0,0,0)
		function uw:DoClick()
			for k,v in pairs(l:GetSelected()) do
				v:SetColumnText(3, num:GetValue())
			end
		end

		function l:OnRowSelected(i, line)
			local num = 0
			for k,v in pairs(self:GetLines()) do
				if v:IsLineSelected() then
					num = num + 1
				end
			end

			lbl:SetText(num.. " Selected")
			ur:SetDisabled(num < 1)
			uw:SetDisabled(num < 1)
		end

		function p:SetValue(t)
			l:Clear()
			for k,v in pairs(t) do
				local wep = weapons.Get(k)
				l:AddLine(k, wep.PrintName or "UNKNOWN", v)
			end
		end
		
		function p:GetValue()
			local t = {}
			for k,v in pairs(l:GetLines()) do
				t[v:GetValue(1)] = tonumber(v:GetValue(3)) or 100
			end
			return t
		end

		function plus:DoClick()
			local _,data = entry:GetSelected()
			local wep = weapons.Get(data)
			l:AddLine(data, wep.PrintName or "UNKNOWN", num:GetValue())

			entry:SetValue("")
		end

		return p
	end
})

-- Option Set: A dropdown containing a selection of options networked from the Server.
-- Note: This setting requires implementing GetOptions which should return a table of pairs: {Option = data, Display = pretty}
-- where 'data' is the value networked, and 'pretty' is a pretty display name for the dropdown. If pretty doesn't exist, data is used in its place.
local optionset = {
	NetWrite = net.WriteString,
	NetRead = net.ReadString,
	GetOptions = function()
		return {} -- Nothing by default! You must implement this if you want any options!
	end,
}
if SERVER then
	util.AddNetworkString("nzu_optionset")
	local function networkoptions(ext, s, ply)
		if type(ext) == "string" then ext = nzu.GetExtension(ext) end
		if ext then
			local setting = ext:GetSettingsMeta()[s]
			if setting and setting.GetOptions then
				local tbl = setting.GetOptions()
				local num = #tbl

				if num > 0 then
					net.Start("nzu_optionset")
						net.WriteString(k)
						net.WriteUInt(num, 16)
						for i = 1,num do
							net.WriteString(tbl[i].Option)
							net.WriteString(tbl[i].Display)
						end
					net.Send(ply)
				end
			end
		end
	end

	-- In Sandbox, cache all option sets created and network them to any player joining
	if NZU_SANDBOX then
		local sets = {}
		optionset.Create = function(ext, setting)
			sets[setting] = ext
		end

		hook.Add("PlayerInitialSpawn", "nzu_Extensions_OptionSetNetwork", function(ply)
			for k,v in pairs(sets) do
				networkoptions(v, k, ply)
			end
		end)
	else
		-- In nZombies, only respond to admin requests
		net.Receive("nzu_optionset", function(len, ply)
			if nzu.IsAdmin(ply) then
				local ext = net.ReadString()
				local id = net.ReadString()

				networkoptions(ext, id, ply)
			end
		end)
	end
else
	local function readoptions()
		local id = net.ReadString()
		local num = net.ReadUInt(16)

		local tbl = {}
		for i = 1,num do
			local t = {}
			t.Option = net.ReadString()
			t.Display = net.ReadString()

			table.insert(tbl, t)
		end

		return id, tbl
	end

	local sets
	if NZU_SANDBOX then
		sets = {}
	end

	net.Receive("nzu_optionset", function()
		local id,tbl = readoptions()
		if sets then sets[id] = tbl end -- Only do this in Sandbox pretty much

		hook.Run("nzu_OptionSetUpdated", id, tbl)
	end)

	optionset.Panel = function(parent, ext, setting)
		local p = vgui.Create("DComboBox", parent)

		function p:Populate(id, tbl)
			if id == setting then
				self:Clear()
				for k,v in pairs(tbl) do
					self:AddChoice(v.Display, v.Option)
				end
			end
		end

		if NZU_SANDBOX then
			if sets and sets[setting] then
				p:Populate(setting, sets[setting])
			end
		else
			-- Request options
			net.Start("nzu_optionset")
				net.WriteString(ext.ID)
				net.WriteString(setting)
			net.SendToServer()
		end
		hook.Add("nzu_OptionSetUpdated", p, p.Populate)

		function p:OnSelect(index, value, data)
			self:Send()
		end

		function p:SetValue(v)
			for k,data in pairs(self.Data) do
				if data == v then
					self:SetText(self:GetOptionText(k))
					self.selected = k
					return
				end
			end

			self.Choices[0] = v
			self.Data[0] = v
			self.selected = 0
			self:SetText(v)
		end

		function p:GetValue()
			local str,data = self:GetSelected()
			return data
		end

		return p
	end
end
nzu.AddExtensionSettingType("OptionSet", optionset)