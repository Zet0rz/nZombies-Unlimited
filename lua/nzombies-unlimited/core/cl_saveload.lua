local officialconfigs = {
	{
		Name = "Breakout",
		Icon = "icon16/computer.png",
		Map = "ttt_kosovos",
	}
}
local localconfigs = {
	
}
local workshopconfigs = {
	
}

nzu.AddSpawnmenuTab("Save/Load", "DPanel", function(panel)
	panel:SetBackgroundColor(Color(150,150,150))
	
	local configpanel = panel:Add("DPanel")
	configpanel:SetWidth(200)
	configpanel:Dock(LEFT)
	
	local header = configpanel:Add("DLabel")
	header:SetText("Configs")
	header:SetFont("DermaLarge")
	header:SetTextColor(Color(0,0,0))
	header:SizeToContents()
	header:SetContentAlignment(5)
	header:Dock(TOP)
	
	local tree = configpanel:Add("DConfigTree")
	tree:Dock(FILL)
	
	local official = tree:AddNode("Official Configs", "icon16/lightning.png")
	official:SetTall(30)
	official:SetBackgroundColor(Color(10,10,10))
	local l = official:Add("DLabel")
	l:SetText("Official Configs")
	l:SetFont("DermaLarge")
	l:SetContentAlignment(5)
	l:Dock(FILL)
	for k,v in pairs(officialconfigs) do
		local n = official:AddNode(v.Name, v.Icon)
	end
	
	local localcfgs = tree:AddNode("Local Configs", "icon16/floppy.png")
	for k,v in pairs(localconfigs) do
		localcfgs:AddNode(v.Name, v.Icon)
	end
	
	local workshopcfgs = tree:AddNode("Workshop Configs", "icon16/settings_wheel.png")
	for k,v in pairs(workshopconfigs) do
		workshopcfgs:AddNode(v.Name, v.Icon)
	end
end, "icon16/floppy_disk.png", "Save your Config or load another")