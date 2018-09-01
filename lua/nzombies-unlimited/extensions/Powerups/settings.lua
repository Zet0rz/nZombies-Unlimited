
local EXTENSION = nzu.Extension()

local powerups = {
	"Nuke",
	"Instakill",
	"Double Points",
	"Fire Sale",
	"Carpenter",
}

EXTENSION.Settings = {
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
}

if CLIENT then
	function EXTENSION:Panel()
		local p = vgui.Create("DPanel")
		p:SetBackgroundColor(Color(255,0,0))
		p:SetSize(100,500)

		return p
	end
end