
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
	if IsValid(tab) and tab.Initialized then
		local p = vgui.Create(paneltype, tab)
		func(p)
		tab:AddSheet(name, p, icon, false, false, tooltip)
		tabs[name].panel = p
	end
end

function nzu.GetSpawnmenuTab(name)
	return tabs[name] and tabs[name].panel
end

local function createtabs(tab)
	for k,v in pairs(tabs) do
		if not IsValid(v.panel) then
			local p = vgui.Create(v.type, tab)
			p:SetSkin("nZombies Unlimited")
			v.func(p)
			tab:AddSheet(k, p, v.icon, false, false, v.tooltip)
			v.panel = p
		end
	end
end

spawnmenu.AddCreationTab(tabname, function()
	tab = vgui.Create("DPropertySheet")
	tab:SetSkin("nZombies Unlimited")

	if IsValid(LocalPlayer()) then createtabs(tab) end
	
	return tab
end, "icon16/briefcase.png", 1000, "nZombies Unlimited - Control Panel")

hook.Add("InitPostEntity", "nzu_Spawnmenu_Initialize", function()
	if IsValid(tab) then createtabs(tab) end
end)