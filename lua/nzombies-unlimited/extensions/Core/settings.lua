local EXTENSION = nzu.Extension()

local settings = {
	["Starting Points"] = {
		Type = TYPE_NUMBER,
		Default = 500,
		Parse = function(n) return math.Round(n) end
	},
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

		local points = SettingPanel("Starting Points", p_points)
		points:Dock(FILL)

		p_points:SetTall(25)

		return p
	end

	return settings, panelfunc
end

return settings