
local function generatesettingspanel(ext, f)
	local p = vgui.Create("nzu_ExtensionPanel", f)
	p:SetExtension(ext)
	return p
end

local tounload = {}
local function checkboxchange(self,b)
	if not nzu.IsExtensionLoaded(self.Extension) then
		if b then
			nzu.RequestLoadExtension(self.Extension)
		end
	else
		if b then
			tounload[self.Extension] = nil
		else
			tounload[self.Extension] = true
		end
		
		local num = table.Count(tounload)
		self.SaveButton:SetText(num > 0 and "Save and Unload Extensions ("..num..")" or "Save to Settings file")
	end
end

local function generateinfopanel(details, f)
	local p = vgui.Create("DPanel", f)
	local lbl = vgui.Create("DLabel", p)
	lbl:SetText("Extension not loaded.")
	lbl:SetTextColor(Color(255,0,0))
	lbl:SetContentAlignment(5)
	lbl:SetFont("Trebuchet18")
	lbl:DockMargin(5,5,5,0)
	lbl:Dock(TOP)
	
	local desc = p:Add("DLabel")
	desc:Dock(TOP)
	desc:SetText(details.Name)
	desc:SizeToContentsY()
	desc:SetFont("Trebuchet18")
	desc:DockMargin(5,5,5,0)
	desc:SetTextColor(Color(255,200,180))
	
	local d = p:Add("DLabel")
	d:Dock(TOP)
	d:SetText(details.Description or "")
	d:SetWrap(true)
	d:SetAutoStretchVertical(true)
	d:SetTextInset(5,0)
	
	local auth = p:Add("Panel")
	auth:Dock(TOP)
	auth:DockMargin(5,5,5,0)
	local atxt = auth:Add("DLabel")
	atxt:SetFont("Trebuchet18")
	atxt:SetText("Author(s): ")
	atxt:SetTextColor(Color(255,200,180))
	atxt:Dock(LEFT)
	atxt:SizeToContents()
	local authors = auth:Add("DLabel")
	authors:SetText(details.Author)
	authors:Dock(FILL)
	auth:SizeToChildren(false,true)
	
	if details.Prerequisites and #details.Prerequisites > 0 then
		local preq = p:Add("DLabel")
		preq:SetFont("Trebuchet18")
		preq:SetText("Requires:")
		preq:SetTextColor(Color(255,200,180))
		preq:DockMargin(5,5,5,0)
		preq:Dock(TOP)
		
		for k,v in pairs(details.Prerequisites) do
			local id = p:Add("DLabel")
			local det = nzu.GetExtensionDetails(v)
			id:SetText("- "..(det and det.Name or "[Unknown Name]") .. " ["..v.."]")
			id:SetTextInset(15,0)
			if nzu.IsExtensionLoaded(v) then
				id:SetTextColor(Color(100,255,100))
			else
				id:SetTextColor(Color(255,100,100))
				id.Think = function(s)
					if nzu.IsExtensionLoaded(v) then
						s:SetTextColor(Color(255,100,100))
						s.Think = function() end
					end
				end
			end
			id:Dock(TOP)
		end
	end
	
	p:SizeToChildren(false,true)
	return p
end

local columns = 3
local pad = 3
nzu.AddSpawnmenuTab("Extension Settings", "DPanel", function(panel)
	panel.ExtensionPanels = {}

	local top = panel:Add("DPanel")
	top:SetTall(60)
	top:Dock(TOP)
	top:DockPadding(5,5,5,5)

	local save = top:Add("DButton")
	save:SetText("Save to Settings file")
	save:Dock(RIGHT)
	save:SetWide(300)
	save.DoClick = function(s)
		if table.Count(tounload) > 0 then
			local txt = "Do you wish to Save and reload the map? The following Extensions will be unloaded: "
			for k,v in pairs(tounload) do
				txt = txt .. "\n- "..k
			end
			Derma_Query(txt, "Config load confirmation",
				"Reload the map and Unload Extensions", function()
					nzu.RequestUnloadExtensions(table.GetKeys(tounload))
				end,
				"Cancel"
			):SetSkin("nZombies Unlimited")
		else
			nzu.RequestSaveConfigSettings(nzu.CurrentConfig)
		end
	end

	local curconfig = top:Add("nzu_ConfigPanel")
	curconfig:Dock(LEFT)
	curconfig:SetWide(400)

	local fill = panel:Add("Panel")
	fill:Dock(FILL)

	local block = panel:Add("DPanel")
	block:SetBackgroundColor(Color(50,0,0,200))
	block:SetZPos(1)
	block:Dock(FILL)

	if nzu.CurrentConfig then
		curconfig:SetConfig(nzu.CurrentConfig)
		block:SetVisible(false)
	else
		curconfig:SetVisible(false)
	end
	save:SetDisabled(not nzu.CurrentConfig or nzu.CurrentConfig.Type ~= "Local")

	local alert = block:Add("DLabel")
	alert:SetFont("Trebuchet24")
	alert:SetText("Load a Local Config to change its Settings.")
	alert:Dock(FILL)
	alert:SetContentAlignment(5)
	alert:SetTextColor(Color(255,0,0))
	
	hook.Add("nzu_ConfigLoaded", curconfig, function(s,config)
		if config then
			curconfig:SetConfig(config)
			curconfig:SetVisible(true)
		else
			curconfig:SetVisible(false)
		end
		local cantedit = not config or config.Type ~= "Local"
		block:SetVisible(cantedit)
		save:SetDisabled(cantedit)
	end)

	panel.Lists = {}
	for i = 1,columns do
		local p = fill:Add("DCategoryList")
		p:Dock(LEFT)
		p:DockMargin(pad,2,0,2)

		panel.Lists[i] = p
	end

	function panel:PerformLayout()
		local w = (self:GetWide() - pad)/columns - pad
		for i = 1,columns do
			panel.Lists[i]:SetWide(w)
		end
	end

	local loadedexts = 1
	for k,v in pairs(nzu.GetAvailableExtensions()) do
		local f = panel.Lists[loadedexts]:Add((v and v.Name or "[Unknown Name]") .. " ["..k.."]")
		local checkbox = f.Header:Add("DCheckBoxLabel")
		checkbox:Dock(RIGHT)
		checkbox:SetWide(20)
		checkbox:SetChecked(nzu.IsExtensionLoaded(k))
		
		
		checkbox.Extension = k
		if k ~= "Core" and nzu.IsAdmin(LocalPlayer()) then
			checkbox.SaveButton = save
			checkbox.OnChange = checkboxchange
			checkbox:SetDisabled(false)
		else
			checkbox:SetDisabled(true)
		end
		
		
		local p = nzu.IsExtensionLoaded(k) and generatesettingspanel(k, f) or generateinfopanel(v, f)
		f.LoadedCheckbox = checkbox
		f:SetContents(p)
		if not nzu.IsExtensionLoaded(k) and f:GetExpanded() then
			f:Toggle()
		end

		loadedexts = loadedexts < columns and loadedexts + 1 or 1
		panel.ExtensionPanels[v] = f
	end

	hook.Add("nzu_ExtensionLoaded", panel, function(s, ext)
		local pnl = s.ExtensionPanels[ext]
		if pnl then
			pnl.LoadedCheckbox:SetChecked(true)
			
			if pnl.Contents then pnl.Contents:Remove() end
			local p = generatesettingspanel(ext)
			pnl:SetContents(p)
		end
	end)
end, "icon16/plugin.png", "Control Config Settings and Extensions")

