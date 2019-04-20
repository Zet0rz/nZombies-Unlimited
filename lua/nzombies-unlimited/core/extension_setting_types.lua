
-- String: A text entry that will send whenever it loses focus
nzu.AddExtensionSettingType("String", {
	NetRead = net.ReadString,
	NetWrite = net.WriteString,
	Panel = {
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
	}
})

-- Number: A networked double with a Number Wang
nzu.AddExtensionSettingType("Number", {
	NetRead = net.ReadDouble,
	NetWrite = net.WriteDouble,
	Panel = {
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
	}
})

-- Boolean: A true/false value that appears as a checkbox, networked whenever clicked
nzu.AddExtensionSettingType("Boolean", {
	NetRead = net.ReadBool,
	NetWrite = net.WriteBool,
	Panel = {
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
	}
})

-- Vector: 3 number wangs with an associated Save button. Uses DVectorEntry (included in nZU)
nzu.AddExtensionSettingType("Vector", {
	NetRead = net.ReadVector,
	NetWrite = net.WriteVector,
	Panel = {
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
	}
})

-- Angle: 3 number wangs with an associated Save button, similar to Vector
nzu.AddExtensionSettingType("Angle", {
	NetRead = net.ReadAngle,
	NetWrite = net.WriteAngle,
	Panel = {
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
	}
})

-- Matrix: 4x4 number wangs with an associated Save button, also similar to Angle and Vector
nzu.AddExtensionSettingType("Matrix", {
	NetRead = net.ReadMatrix,
	NetWrite = net.WriteMatrix,
	Panel = {
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
	}
})

-- Color: A color select with a Save button
nzu.AddExtensionSettingType("Color", {
	NetRead = net.ReadColor,
	NetWrite = net.WriteColor,
	Load = function(t) return IsColor(t) and t or Color(t.r, t.g, t.b, t.a) end,
	Panel = {
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
	}
})

-- Weapon: A text field dropdown that contains all installed weapons, including a search field to filter the dropdown
nzu.AddExtensionSettingType("Weapon", {
	NetWrite = net.WriteString,
	NetRead = net.ReadString,
	Panel = {
		Create = function(parent, ext, setting)
			local p = vgui.Create("DSearchComboBox", parent)

			p:AddChoice("  [None]", "") -- Allow the choice of none
			for k,v in pairs(weapons.GetList()) do
				p:AddChoice((v.PrintName or "").." ["..v.ClassName.."]", v.ClassName)
			end
			p:SetAllowCustomInput(true)

			function p:OnSelect(index, value, data)
				self:Send()
			end

			return p
		end,
		Set = function(p,v)
			for k,class in pairs(p.Data) do
				if class == v then
					p:SetText(p:GetOptionText(k))
					p.selected = k
					return
				end
			end

			p.Choices[0] = v
			p.Data[0] = v
			p.selected = 0
			p:SetText(v)
		end,
		Get = function(p)
			local str,data = p:GetSelected()
			return data
		end,
	}
})