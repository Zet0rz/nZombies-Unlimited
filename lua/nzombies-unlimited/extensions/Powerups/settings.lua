
local EXTENSION = nzu.Extension()

local powerups = {
	"Nuke",
	"Instakill",
	"Double Points",
	"Fire Sale",
	"Carpenter",
}

local settings = {
	["Enabled Powerups"] = {
		Type = TYPE_BOOL,
		NetSend = function(self, val)
			for k,v in pairs(powerups) do
				net.WriteBool(val[v])
			end
		end,
		NetRead = function(self)
			local tbl = {}
			for k,v in pairs(powerups) do
				tbl[v] = net.ReadBool()
			end
		end,
		Default = {},
	},
	["TestString"] = {
		Type = TYPE_COLOR,
		Default = Color(255,0,0),
	},
}

if CLIENT then
	local panelfunc = function()
		local p = vgui.Create("DPanel")
		p:SetBackgroundColor(Color(100,100,100))
		p:SetTall(300)

		local pnl = SettingPanel("Enabled Powerups")
		pnl:SetParent(p)
		pnl:SetPos(20, 50)

		local pnl2 = SettingPanel("TestString")
		pnl2:SetParent(p)
		--pnl2:SetWide(200)
		pnl2:SetPos(20, 100)

		return p
	end

	return settings, panelfunc
end

return settings