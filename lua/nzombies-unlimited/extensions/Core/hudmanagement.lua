local EXTENSION = nzu.Extension()
local HUD = EXTENSION.HUD or {}
EXTENSION.HUD = HUD

if CLIENT then
	local components = {}
	function HUD.RegisterComponent(f)
		table.insert(components, f)
	end

	hook.Add("HUDPaint", "nzu_HUD_Components", function()
		for k,v in pairs(components) do
			v()
		end
	end)
end