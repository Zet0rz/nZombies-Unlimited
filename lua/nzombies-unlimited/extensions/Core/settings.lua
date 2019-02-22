local EXTENSION = nzu.Extension()

local settings = {
	["StartWeapon"] = {
		Type = TYPE_STRING,
		Default = "weapon_pistol",
	},

	["StartPoints"] = {
		Type = TYPE_NUMBER,
		Default = 500,
		Parse = function(n) return math.Round(n) end
	},

	-- HUD Management
	-- This one is rather complicated and requires custom panels and networking
	-- but it's a good demonstration of how to do this
	-- This is a table of strings
	["HUDComponents"] = {
		Default = {Round = "Unlimited", Points = "Unlimited"},
		NetSend = function(val)
			local num = table.Count(val)
			net.WriteUInt(num, 8) -- We assume there's not gonna be more than 255 component types
			for k,v in pairs(val) do
				net.WriteString(k)
				net.WriteString(v == "None" and "" or v)
			end
		end,
		NetRead = function()
			local num = net.ReadUInt(8)
			local t = {}
			for i = 1,num do
				local k = net.ReadString()
				local v = net.ReadString()
				if v ~= "" then
					t[k] = v
				end
			end
			return t
		end,
		Client = true, -- Network this to all clients whenever changed
		CustomPanel = {
			Create = function(parent, ext)
				local p = vgui.Create("Panel", parent)
				local s = p:Add("DScrollPanel")
				local l = p:Add("DListLayout")
				l:Dock(FILL)
				p.Comboboxes = {}
				p.Choices = {}

				local hud = ext.HUD
				local types = hud.GetComponentTypes()
				for k,v in pairs(types) do
					local comps = hud.GetComponents(v)

					local bar = l:Add("Panel")
					bar:Dock(TOP)
					bar:SetTall(20)
					local l = bar:Add("DLabel")
					l:SetText(v)
					l:Dock(LEFT)
					l:SetWide(100)

					local combo = bar:Add("DComboBox")
					combo:Dock(FILL)
					combo:AddChoice("None")

					for k2,v2 in pairs(comps) do
						combo:AddChoice(v2)
					end
					function combo:OnSelect(index, value, data)
						p.Choices[v] = value
					end

					p.Comboboxes[v] = combo

					print(v)
					PrintTable(comps)
				end

				local save = p:Add("DButton")
				save:SetText("Save")
				save:Dock(BOTTOM)
				save:SetTall(20)
				save:DockMargin(5,5,5,5)
				function save:DoClick()
					p:Send()
				end
				s:Dock(FILL)

				return p
			end,
			Set = function(p,v)
				for k2,v2 in pairs(v) do
					p.Choices[k2] = v2
					if p.Comboboxes[k2] then
						p.Comboboxes[k2]:SetValue(v2)
					end
				end
				for k2,v2 in pairs(p.Comboboxes) do
					if not p.Choices[k2] then
						p.Comboboxes[k2]:SetValue("None")
					end
				end
			end,
			Get = function(p,v)
				return p.Choices
			end
		},
		ClientNotify = "OnHUDComponentsChanged" -- Call the callback
	}
}

if CLIENT then
	local panelfunc = function(p, SettingPanel)
		--p:SetBackgroundColor(Color(100,100,100))

		local p_points = vgui.Create("Panel")
		p_points:Dock(TOP)
		p_points:DockPadding(5,2,5,2)
		p_points:SetParent(p)
		local lbl = p_points:Add("DLabel")
		lbl:SetText("Starting Points")
		lbl:Dock(LEFT)
		lbl:SizeToContentsX()
		lbl:DockMargin(0,0,10,0)

		local points = SettingPanel("StartPoints", p_points)
		points:Dock(FILL)

		p_points:SetTall(25)

		local p_wep = p:Add("Panel")
		p_wep:Dock(TOP)
		p_wep:DockPadding(5,2,5,2)
		local p_wepl = p_wep:Add("DLabel")
		p_wepl:SetText("Starting Weapon")
		p_wepl:Dock(LEFT)
		p_wepl:SizeToContentsX()
		p_wepl:DockMargin(0,0,10,0)
		local p_wepp = SettingPanel("StartWeapon", p_wep)
		p_wepp:Dock(FILL)
		p_wep:SetTall(25)

		local lbl_hud = p:Add("DLabel")
		lbl_hud:Dock(TOP)
		lbl_hud:SetText("HUD Components:")
		lbl_hud:DockMargin(5,2,5,10)
		lbl_hud:SetFont("Trebuchet18")

		local huds = SettingPanel("HUDComponents", p)
		huds:Dock(TOP)
		huds:SetTall(100)
		huds:DockMargin(5,5,5,5)

		return p
	end

	return settings, panelfunc
end

return settings