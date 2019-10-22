local settings = {
	["WeaponList"] = {
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
		Notify = function(val, key, ext)
			if NZU_NZOMBIES then timer.Simple(0.1, function() ext.ReloadModelsList() end) end
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
	},
}

if CLIENT then
	local panelfunc = function(p, SettingPanel)
		local weps = SettingPanel("WeaponList", p)
		weps:Dock(TOP)
	end
	return settings, panelfunc
end

return settings