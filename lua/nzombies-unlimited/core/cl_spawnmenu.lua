
local tabname = "nZombies Unlimited"

local tab
local tabs = {}
function nzu.AddSpawnmenuTab(name, paneltype, func, icon, tooltip)
	if tabs[name] and IsValid(tabs[name].panel) then
		for k,v in pairs(tabs[name].panel:GetChildren()) do v:Remove() end
		func(tabs[name].panel)
		return
	end

	tabs[name] = {type = paneltype, func = func, icon = icon, tooltip = tooltip}
	if IsValid(tab) then
		local p = vgui.Create(paneltype, tab)
		func(p)
		tab:AddSheet(name, p, icon, false, false, tooltip)
		tabs[name].panel = p
	end
end

function nzu.GetSpawnmenuTab(name)
	return tabs[name] and tabs[name].panel
end

spawnmenu.AddCreationTab(tabname, function()
	tab = vgui.Create("DPropertySheet")
	for k,v in pairs(tabs) do
		local p = vgui.Create(v.type, tab)
		v.func(p)
		tab:AddSheet(k, p, v.icon, false, false, v.tooltip)
		v.panel = p
	end
	return tab
end, "icon16/control_repeat_blue.png", 1000, "nZombies Unlimited - Control Panel")

