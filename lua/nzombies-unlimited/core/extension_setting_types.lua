--[[
Extension Setting Types
This file defines the built-in Extension setting types you can use. You can add your own using nzu.AddExtensionSettingType, or simply by filling in your own Extension's Settings table with all these values

Available types:
- "String": A simple string
- "Number": A double
- "Boolean": A boolean
- "Vector": A vector
- "Angle": An angle
- "Matrix": A 4x4 matrix
- "Color": A Color object
- "Weapon": A string representing the classname of a weapon
- "WeightedWeaponList": A table with keys being weapon classnames, and values being a numerical weight
- "OptionSet": A dropdown listing options from a predefined set of options. Requires additional field "Options" which can be a sequential table of options, or a key/value pair for data behind each option.
- "FileDir": A dropdown listing folders found in a specific path. Requires additional field "Path" which is always relative to "GAME" (file.Find(path, "GAME") <- Directories or files from this).
	Additionally requires either field "Directories = true" or "Files = true" or both to control whether to show files or folders (or both).
]]


-- String: A text entry that will send whenever it loses focus
nzu.AddExtensionSettingType("String", {
	NetType = TYPE_STRING, -- This points at net.WriteString/net.ReadString
	Panel = function(self, parent)
		local p = vgui.Create("DTextEntry", parent)
		p:SetTall(20)

		function p:OnFocusChanged(b)
			if not b then self:Send() end -- Trigger networking on text field focus lost
		end
		function p:GetValue() return self:GetText() end

		return p
	end
})

-- Number: A networked double with a Number Wang
nzu.AddExtensionSettingType("Number", {
	NetType = TYPE_NUMBER,
	Parse = function(self, v)
		local num = v
		if self.Integer then return math.Round(v) end
		if self.Min then num = math.Max(self.Min, num) end
		if self.Max then num = math.Min(self.Max, num) end
		return num
	end,
	Panel = function(self, parent)
		local p = vgui.Create("DNumberWang", parent)
		p:SetMinMax(self.Min, self.Max)
		p:SetTall(20)

		function p:OnValueChanged()
			if self.Send then self:Send() end -- Trigger networking whenever it changes
		end

		return p
	end
})

-- Boolean: A true/false value that appears as a checkbox, networked whenever clicked
nzu.AddExtensionSettingType("Boolean", {
	NetType = TYPE_BOOL,
	Panel = function(self, parent)
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
	NetType = TYPE_VECTOR,
	Panel = function(self, parent)
		local p = vgui.Create("Panel", parent)

		p.S = p:Add("DButton")
		p.S:SetText("Save")
		p.S:Dock(RIGHT)
		p.S:SetWide(50)

		p.V = p:Add("DVectorEntry")
		p.V:Dock(FILL)

		p:SetTall(20)

		p.S.DoClick = function() p:Send() end -- Network on button click
		function p:SetValue(v) self.V:SetVector(v) end
		function p:GetValue() return self.V:GetVector() end

		return p
	end
})

-- Angle: 3 number wangs with an associated Save button, similar to Vector
nzu.AddExtensionSettingType("Angle", {
	NetType = TYPE_ANGLE,
	Panel = function(self, parent)
		local p = vgui.Create("Panel", parent)

		p.S = p:Add("DButton")
		p.S:SetText("Save")
		p.S:Dock(RIGHT)
		p.S:SetWide(50)

		p.A = p:Add("DAngleEntry")
		p.A:Dock(FILL)

		p:SetTall(20)

		p.S.DoClick = function() p:Send() end -- Network on button click
		function p:SetValue(v) self.A:SetAngles(v) end
		function p:GetValue() return self.A:GetAngles() end

		return p
	end
})

-- Matrix: 4x4 number wangs with an associated Save button, also similar to Angle and Vector
nzu.AddExtensionSettingType("Matrix", {
	NetType = TYPE_MATRIX,
	Panel = function(self, parent)
		local p = vgui.Create("Panel", parent)

		p.S = p:Add("DButton")
		p.S:SetText("Save")
		p.S:Dock(BOTTOM)
		p.S:SetTall(20)

		p.M = p:Add("DMatrixEntry")
		p.M:Dock(FILL)

		p:SetTall(100)

		p.S.DoClick = function() p:Send() end -- Network on button click

		function p:SetValue(v) self.M:SetMatrix(v) end
		function p:GetValue() return self.M:GetMatrix() end

		return p
	end
})

-- Color: A color select with a Save button
nzu.AddExtensionSettingType("Color", {
	NetType = TYPE_COLOR,
	Parse = function(self, t) return IsColor(t) and t or Color(t.r, t.g, t.b, t.a) end,
	Panel = function(self, parent)
		local p = vgui.Create("Panel", parent)

		p.S = p:Add("DButton")
		p.S:SetText("Save")
		p.S:Dock(BOTTOM)
		p.S:SetTall(20)

		p.C = p:Add("DColorMixer")
		p.C:Dock(FILL)

		p:SetTall(185)

		p.S.DoClick = function() p:Send() end -- Network on button click

		function p:SetValue(v) self.C:SetColor(v) end
		function p:GetValue() local c = self.C:GetColor() return Color(c.r,c.g,c.b,c.a) end

		return p
	end
})

-- Weapon: A text field dropdown that contains all installed weapons, including a search field to filter the dropdown
nzu.AddExtensionSettingType("Weapon", {
	NetType = TYPE_STRING, -- Weapons are just class strings
	Panel = function(self, parent)
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

		p:SetTall(20)

		return p
	end
})

-- Weighted Weapon List: A list of weapons where each weapon has a weight associated to it. Its internal value is a table where each weapon class is the key,
-- and the associated weight is the value. This is used for example in the Mystery Box weapons list.
nzu.AddExtensionSettingType("WeightedWeaponList", {
	Default = {}, -- Default is empty
	NetRead = function()
		local t = {}
		local num = net.ReadUInt(16)
		for i = 1,num do
			local class = net.ReadString()
			t[class] = net.ReadUInt(16)
		end
		return t
	end,
	NetWrite = function(self, t)
		local t2 = table.GetKeys(t)
		local num = #t2
		net.WriteUInt(num, 16)
		for i = 1,num do
			local class = t2[i]
			net.WriteString(class)
			net.WriteUInt(t[class], 16)
		end
	end,
	Panel = function(self, parent)
		local p = vgui.Create("Panel", parent)
		p:SetTall(350)
		--p:DockMargin(10,10,10,10)

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

nzu.AddExtensionSettingType("OptionSet", {

	-- We could have Parse here which would change it to Extension:SetSetting(key, "option_id").
	-- But it causes unnecessary back-and-forth parsing between panel and networking
	-- Instead, it will just be Extension:SetSetting(key, Extension.Settings[key].Options["option_id"]) i.e. the data itself

	--Parse = function(self, key) -- Whenever the setting is set, it gets parsed to the data behind the option
		--return self.Options[key]
	--end,

	NetWrite = function(self, data)
		local key
		for k,v in pairs(self.Options) do
			if v == data then
				key = k
				break
			end
		end

		net.WriteString(key)
	end,
	NetRead = function(self)
		local key = net.ReadString()
		return self.Options[key]
	end,
	Panel = function(self, parent)
		local p = vgui.Create("DComboBox", parent)

		for k,v in pairs(self.Options) do
			p:AddChoice(k, v)
		end

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
})


nzu.AddExtensionSettingType("FileDir", {
	NetType = TYPE_STRING,
	Panel = function(self, parent)
		local p = vgui.Create("DSearchComboBox", parent)

		local files,dirs = file.Find(self.Path, "GAME")
		p:AddChoice("  [None]", "") -- Allow the choice of none
		if self.Files then
			for k,v in pairs(files) do
				p:AddChoice(self.Directories and v or string.StripExtension(v), v)
			end
		end
		if self.Directories then
			for k,v in pairs(dirs) do
				p:AddChoice(v)
			end
		end
		p:SetAllowCustomInput(true)

		function p:OnSelect(index, value, data)
			self:Send()
		end

		function p:SetValue(val)
			self:SetText(val)

			for k,v in pairs(self.Data) do
				if val == v then
					self.selected = k
					return
				end
			end

			self.Choices[0] = val
			self.Data[0] = val
			self.selected = 0
		end

		function p:GetValue()
			return self:GetSelected()
		end

		return p
	end
})