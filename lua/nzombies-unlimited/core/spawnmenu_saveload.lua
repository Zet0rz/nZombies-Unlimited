local headerfont = "Trebuchet24"
local namefont = "Trebuchet24"
local textfont = "Trebuchet18"

local configpaneltall = 60
nzu.AddSpawnmenuTab("Save/Load", "DPanel", function(panel)
	--panel:SetSkin("nZombies Unlimited")
	--panel:SetBackgroundColor(Color(150,150,150))
	local editedconfig
	
	local configpanel = panel:Add("DPanel")
	configpanel:SetWidth(400)
	--configpanel:SetBackgroundColor(Color(40,30,30))
	configpanel:Dock(LEFT)

	local infopanel = panel:Add("DPanel")
	infopanel:Dock(FILL)
	infopanel:DockPadding(30,30,30,30)

	-- Top of the config scroll list, we find info about currently loaded configs or new configs
	local curpanel = configpanel:Add("DPanel")
	curpanel:Dock(TOP)
	curpanel:SetTall(70 + configpaneltall)
	curpanel.m_bDrawCorners = true
	curpanel:DockMargin(5,5,0,25)
	local curtop = curpanel:Add("Panel")
	curtop:Dock(TOP)
	curtop:SetTall(35)
	local curloaded = curtop:Add("DLabel")
	curloaded:SetText("Current Config:")
	curloaded:SetFont(headerfont)
	curloaded:DockMargin(5,5,5,5)
	curloaded:Dock(FILL)

	local unload = curtop:Add("DButton")
	unload:SetText("Unload")
	unload:SetVisible(false)
	unload:Dock(RIGHT)
	unload:SetWide(100)
	unload:DockMargin(5,5,10,5)

	local loadedpnl = curpanel:Add("DPanel")
	loadedpnl:Dock(TOP)
	loadedpnl:SetTall(configpaneltall)
	loadedpnl.Paint = function(s,w,h)
		surface.SetDrawColor(50,50,50,230)
		surface.DrawRect(0,0,w,h)
	end
	local loadedcfg = loadedpnl:Add("nzu_ConfigPanel")
	loadedcfg:Dock(FILL)
	loadedcfg:SetVisible(false)
	loadedcfg.m_bDrawCorners = false
	
	local noloaded = loadedpnl:Add("DLabel")
	noloaded:SetText("No Config currently loaded.")
	noloaded:Dock(FILL)
	noloaded:SetContentAlignment(5)
	noloaded:SetFont(textfont)

	local createbutton = curpanel:Add("DButton")
	createbutton:Dock(FILL)
	createbutton:SetText("Create new Config ...")
	createbutton:DockMargin(10,7,10,7)

	local function updateloadedconfig(s,config)
		editedconfig = config
		if config then
			loadedcfg:SetConfig(config)
			loadedcfg:SetVisible(true)
			noloaded:SetVisible(false)
			createbutton:SetText("Create new editable copy ...")
			unload:SetVisible(true)
		else
			loadedcfg:SetVisible(false)
			noloaded:SetVisible(true)
			createbutton:SetText("Create new Config ...")
			unload:SetVisible(false)
		end
	end
	if nzu.CurrentConfig then updateloadedconfig(nil, nzu.CurrentConfig) end
	hook.Add("nzu_ConfigLoaded", curpanel, updateloadedconfig)

	local installed = configpanel:Add("DLabel")
	installed:SetText("Installed Configs:")
	installed:SetFont(headerfont)
	installed:DockMargin(10,5,5,5)
	installed:Dock(TOP)

	local configlist = configpanel:Add("nzu_ConfigList")
	configlist:Dock(FILL)
	configlist:DockMargin(5,0,0,5)
	configlist:SetPaintBackground(true)
	configlist:SetSelectable(true)
	configlist:LoadConfigs()
	
	local img = infopanel:Add("DImage")
	img:SetImage("vgui/black.png")
	img:Dock(TOP)
	img:DockMargin(0,0,0,15)
	function img:PerformLayout()
		local w = self:GetWide()
		self:SetTall(w/16 * 9)
	end

	local img_but = img:Add("DButton")
	img_but:Dock(FILL)
	img_but:SetText("")
	img_but:SetVisible(false)
	
	local editpanel = infopanel:Add("Panel")
	editpanel:Dock(FILL)
	
	local addonarea = editpanel:Add("Panel")
	addonarea:DockMargin(15,0,0,0)
	addonarea:Dock(RIGHT)
	addonarea:SetWide(200)
	
	wid = addonarea:Add("Panel")
	wid:DockMargin(0,0,0,0)
	wid:Dock(TOP)
	local widheader = wid:Add("DLabel")
	widheader:SetText("Config Workshop ID")
	widheader:SetFont(headerfont)
	widheader:Dock(FILL)
	local widinfo = wid:Add("DImage")
	widinfo:SetImage("icon16/information.png")
	widinfo:Dock(RIGHT)
	widinfo:DockMargin(0,5,5,5)
	function widinfo:PerformLayout()
		local t = self:GetTall()
		self:SetWide(t)
	end
	widinfo:SetTooltip("Fill this field with the numeric ID of this Config's Workshop addon after it has been uploaded.\nThis will allow users to view your Config's Workshop page from in-game.")
	widinfo:SetMouseInputEnabled(true)

	local widentry = addonarea:Add("DTextEntry")
	widentry:SetPlaceholderText("123456789")
	widentry:SetPlaceholderColor(Color(75,75,75))
	widentry:SetFont(namefont)
	widentry:SetTall(35)
	widentry:Dock(TOP)
	widentry:SetNumeric(true)
	
	local addoncontrol = addonarea:Add("Panel")
	addoncontrol:Dock(TOP)
	addoncontrol:DockMargin(0,15,0,0)
	
	local addonscroll = addonarea:Add("DScrollPanel")
	addonscroll:Dock(FILL)
	addonscroll:SetPaintBackground(true)
	--addonscroll:SetBackgroundColor(Color(50,50,50))
	local addonlist = addonscroll:Add("DListLayout")
	addonlist:Dock(FILL)
	function addonlist:Refresh()
		self.Addons = {}
		for k,v in pairs(engine.GetAddons()) do
			if v.downloaded and v.wsid then
				local p = vgui.Create("Panel")
				p:DockPadding(2,2,2,2)
				local c = p:Add("DCheckBox")
				c:Dock(LEFT)
				c:DockMargin(0,0,5,0)
				c:SetChecked(selected and selected.RequiredAddons[v.wsid] or false)
				function c:PerformLayout()
					self:SetWide(self:GetTall())
				end
				
				local l = p:Add("DLabel")
				l:SetText(v.title)
				l:SetTextColor(Color(200,200,200))
				l:Dock(FILL)
				l:SetContentAlignment(4)
				
				addonlist:Add(p)
				p:Dock(TOP)
				
				p.CheckBox = c
				self.Addons[v.wsid] = {v.title, c}
			end
		end
	end
	addonlist:Refresh()
	
	local addons = addoncontrol:Add("DLabel")
	addons:SetText("Required Addons")
	addons:SetFont(headerfont)
	addons:Dock(FILL)
	
	--local namearea = editpanel:Add("Panel")
	--namearea:SetBackgroundColor(Color(50,255,100))
	--namearea:Dock(TOP)
	
	local nameheader = editpanel:Add("Panel")
	nameheader:Dock(TOP)
	local nhh = nameheader:Add("DLabel")
	nhh:SetFont(headerfont)
	nhh:SetText("Config name")
	nhh:SizeToContents()
	nhh:Dock(LEFT)
	nhh:DockMargin(3,0,0,0)
	
	local mapname = nameheader:Add("DLabel")
	mapname:SetText("File:          || Map: ")
	mapname:SetFont(textfont)
	mapname:Dock(FILL)
	mapname:DockMargin(10,0,0,0)
	mapname:SizeToContents()
	mapname:SetContentAlignment(1)
	
	local configname = editpanel:Add("DTextEntry")
	configname:Dock(TOP)
	configname:SetEnabled(true)
	configname:SetFont(namefont)
	configname:SetPlaceholderText("Config name...")
	configname:SetPlaceholderColor(Color(75,75,75))
	configname:SetTall(35)
	
	local ap = editpanel:Add("Panel")
	ap:DockMargin(0,15,0,0)
	ap:Dock(TOP)
	local ab = ap:Add("DButton")
	ab:SetText("Set to current players")
	ab:Dock(RIGHT)
	ab:SizeToContents()
	
	local authorheader = ap:Add("DLabel")
	authorheader:DockMargin(3,0,0,0)
	authorheader:SetText("Author(s)")
	authorheader:SetFont(headerfont)
	authorheader:Dock(FILL)
	
	local authors = editpanel:Add("DTextEntry")
	authors:SetPlaceholderText("Author(s)...")
	authors:SetPlaceholderColor(Color(75,75,75))
	authors:SetFont(namefont)
	authors:Dock(TOP)
	authors:SetTall(30)
	function ab:DoClick()
		local str = ""
		for k,v in pairs(player.GetHumans()) do
			str = str .. v:Nick()..", "
		end
		str = string.sub(str, 0, #str - 2)
		authors:SetText(str)
	end
	
	local descheader = editpanel:Add("DLabel")
	descheader:DockMargin(3,15,0,0)
	descheader:SetText("Description")
	descheader:SetFont(headerfont)
	descheader:Dock(TOP)
	
	local desc = editpanel:Add("DTextEntry")
	desc:SetMultiline(true)
	desc:SetFont(textfont)
	desc:SetPlaceholderText("Config Description...")
	desc:SetPlaceholderColor(Color(75,75,75))
	desc:Dock(FILL)

	local playbutton = infopanel:Add("DButton")
	playbutton:Dock(BOTTOM)
	playbutton:SetText("Save and Play")
	playbutton:DockMargin(100,10,100,-20)
	playbutton:SetTall(40)
	playbutton:SetFont("Trebuchet24")
	playbutton:SetEnabled(nzu.IsAdmin(LocalPlayer()))
	
	local saveload = infopanel:Add("Panel")
	saveload:DockMargin(0,5,0,0)
	saveload:SetTall(30)
	saveload:Dock(BOTTOM)

	local saveload2 = infopanel:Add("Panel")
	saveload2:DockMargin(0,30,0,0)
	saveload2:SetTall(20)
	saveload2:Dock(BOTTOM)
	
	local reload = saveload:Add("DButton")
	reload:SetText("Reload last saved version")
	local save = saveload:Add("DButton")
	save:SetText("Save Config")

	playbutton.DoClick = function(s)
		local selectedconfig = loadedcfg:IsSelected() and loadedcfg:GetConfig() or configlist:GetSelectedConfig()
		if selectedconfig then
			if selectedconfig == editedconfig then save:DoClick() end
			Derma_Query("Do you wish to change gamemode to NZOMBIES UNLIMITED?", "Mode change confirmation", "Change gamemode", function()
				nzu.RequestPlayConfig(selectedconfig)
			end, "Cancel"):SetSkin("nZombies Unlimited")
		end
	end
	
	function saveload:PerformLayout()
		local w = self:GetWide()/2 + 15
		reload:StretchToParent(0,0,w,0)
		save:StretchToParent(w,0,0,0)
	end

	local delete = saveload2:Add("DButton")
	delete:Dock(LEFT)
	delete:SetText("Delete Config")
	delete:SetWide(150)

	local savemeta = saveload2:Add("DButton")
	savemeta:Dock(RIGHT)
	savemeta:SetText("Save Info")
	savemeta:SetWide(150)

	infopanel:SetZPos(2)
	infopanel:SetVisible(false)
	local noshow = panel:Add("DLabel")
	noshow:Dock(FILL)
	noshow:SetContentAlignment(5)
	noshow:SetFont(headerfont)
	noshow:SetText("<-- Click a Config to display.")

	local addonlist2_Scroll = addonarea:Add("DScrollPanel")
	addonlist2_Scroll:Dock(FILL)
	local addonlist2 = addonlist2_Scroll:Add("DListLayout")
	addonlist2:Dock(FILL)

	-- Control selecting configs
	local function doconfigclick(pnl)
		if not IsValid(pnl) or not pnl.Config then infopanel:SetVisible(false) infopanel.Config = nil return end
		infopanel:SetVisible(true)

		local cfg = pnl.Config
		infopanel.Config = cfg
		configname:SetText(cfg.Name)
		authors:SetText(cfg.Authors)
		desc:SetText(cfg.Description)
		mapname:SetText("File: " .. cfg.Codename .. " || Map: "..cfg.Map)
		widentry:SetText(cfg.WorkshopID or "")

		img:SetImage(nzu.GetConfigThumbnail(cfg) or "vgui/black.png")

		-- Edits and stuff
		if nzu.IsAdmin(LocalPlayer()) and cfg == editedconfig and (cfg.Type == "Local" or cfg.Type == "Unsaved") then
			addonscroll:SetVisible(true)
			addonlist2_Scroll:SetVisible(false)

			save:SetEnabled(true)
			reload:SetText("Reload last saved version")
			reload:SetEnabled(true)
			savemeta:SetEnabled(true)
			delete:SetEnabled(true)

			configname:SetEnabled(true)
			authors:SetEnabled(true)
			desc:SetEnabled(true)
			widentry:SetEnabled(true)
			ab:SetEnabled(true)
			playbutton:SetText("Save and Play")
		else
			addonscroll:SetVisible(false)
			addonlist2_Scroll:SetVisible(true)

			save:SetEnabled(false)
			reload:SetText(cfg == nzu.CurrentConfig and "Reload Config" or "Load Config")
			reload:SetEnabled(nzu.IsAdmin(LocalPlayer()))
			savemeta:SetEnabled(false)
			delete:SetEnabled(cfg.Type == "Local" and nzu.IsAdmin(LocalPlayer()))

			addonlist2:Clear()
			for k,v in pairs(cfg.RequiredAddons) do
				local lbl = addonlist2:Add("DLabelURL")
				lbl:SetText(v)
				lbl:SetURL("https://steamcommunity.com/sharedfiles/filedetails/?id="..k)
				lbl:SetTextColor(steamworks.ShouldMountAddon(k) and Color(0,255,0) or Color(255,0,0))
			end

			configname:SetEnabled(false)
			authors:SetEnabled(false)
			desc:SetEnabled(false)
			widentry:SetEnabled(false)
			ab:SetEnabled(false)

			playbutton:SetText("Load and Play")
		end
	end
	configlist.OnConfigClicked = function(s,cfg,pnl)
		loadedcfg:SetSelected(loadedcfg:GetConfig() == cfg)
		doconfigclick(pnl)
	end

	-- Update through hook if the config updated is the currently viewed one
	hook.Add("nzu_ConfigInfoSaved", infopanel, function(self, config)
		if self.Config == config then
			doconfigclick(self) -- Kinda a fun way to make it update itself, since self.Config is the same
		end
	end)

	-- Create new config button
	createbutton:SetEnabled(nzu.IsAdmin(LocalPlayer()))
	function createbutton:DoClick()
		local frame = vgui.Create("DFrame", panel)
		--frame:SetSkin("nZombies Unlimited")
		frame:SetTitle("Enter Config Codename")
		frame:SetSize(400,130)
		frame:SetDeleteOnClose(true)
		frame:ShowCloseButton(false)
		frame:SetBackgroundBlur(true)
		frame:SetDrawOnTop(true)

		local t1 = frame:Add("DLabel")
		t1:Dock(TOP)
		t1:SetText("Enter Config Codename. Must be a valid folder name.")
		t1:SetContentAlignment(5)

		local errorval
		local function errorlight(s,w,h)
			if errorval then
				surface.SetDrawColor(255,0,0,errorval)
				local x2,y2 = s:GetSize()
				surface.DrawRect(-50, -50, x2+50, y2+50)
				errorval= errorval - FrameTime() * 100
				if errorval <= 0 then
					errorval = nil
				end
			end
		end

		local entry = frame:Add("DTextEntry")
		entry:Dock(TOP)
		entry:SetPlaceholderText("Codename (Config folder name)...")
		entry.PaintOver = errorlight

		local t2 = frame:Add("DLabel")
		t2:Dock(TOP)
		t2:SetText("")
		t2:SetTextColor(Color(255,100,100))
		t2:SetContentAlignment(5)
		t2.PaintOver = errorlight

		local buts = frame:Add("Panel")
		buts:Dock(BOTTOM)
		buts:SetTall(20)

		local save = buts:Add("DButton")
		save:Dock(LEFT)
		save:SetText("Confirm")
		save:SetWide(frame:GetWide()/2 - 10)

		local function doconfirm()
			local val = entry:GetValue()
			if not val or val == "" or string.match(val, "[^%w_%-]") then
				errorval = 255
				t2:SetText("Invalid Codename")
				return
			end

			local result = nzu.ConfigExists(val, "Local")
			if result then
				errorval = 255
				t2:SetText("Local Config by that Codename already exists.")
				return
			elseif result == false then
				t2:SetText("Getting Configs from Server - Try again in a moment ...")
			end

			editedconfig = nzu.CurrentConfig and table.Copy(nzu.CurrentConfig) or {}
			editedconfig.Codename = val
			editedconfig.Type = "Unsaved"
			editedconfig.Name = editedconfig.Name or val
			editedconfig.Map = game.GetMap()
			editedconfig.Authors = editedconfig.Authors or ""
			editedconfig.Description = editedconfig.Description or ""
			editedconfig.RequiredAddons = editedconfig.RequiredAddons or {}

			updateloadedconfig(nil, editedconfig)
			loadedcfg:DoClick()

			frame:Close()
		end
		save.DoClick = doconfirm
		entry.OnEnter = doconfirm

		local cancel = buts:Add("DButton")
		cancel:Dock(RIGHT)
		cancel:SetText("Cancel")
		cancel:SetWide(frame:GetWide()/2 - 10)
		cancel.DoClick = function() frame:Close() end

		frame:SetPos(panel:ScreenToLocal(ScrW()/2 - 200, ScrH()/2 + 65))
		frame:MakePopup()
		frame:DoModal()

		entry:RequestFocus()
	end
	loadedcfg.DoClick = function(s)
		configlist:SelectConfig(s:GetConfig()) -- Update the selected list
		s:SetSelected(true)
		doconfigclick(s)
	end

	local function applyinfo()
		if editedconfig then
			editedconfig.Name = configname:GetValue()
			editedconfig.Description = desc:GetValue()
			editedconfig.Authors = authors:GetValue()
			editedconfig.WorkshopID = widentry:GetValue()
			
			editedconfig.RequiredAddons = {}
			for k,v in pairs(addonlist.Addons) do
				if v[2]:GetChecked() then
					editedconfig.RequiredAddons[k] = v[1]
				end
			end
		end
	end

	save.DoClick = function()
		if editedconfig and (editedconfig.Type == "Local" or editedconfig.Type == "Unsaved") then applyinfo() nzu.RequestSaveConfig(editedconfig) end
	end
	reload.DoClick = function()
		local selectedconfig = configlist:GetSelectedConfig()
		if selectedconfig then
			local txt = "Are you sure you want to load?"
			if nzu.CurrentConfig then txt = txt .. " This will reload the server." end
			Derma_Query(txt, "Config load confirmation",
				"Load the Config", function() nzu.RequestLoadConfig(selectedconfig) end,
				"Cancel"
			):SetSkin("nZombies Unlimited")
		end
	end

	delete.DoClick = function()
		local selectedconfig = configlist:GetSelectedConfig()
		if selectedconfig then
			local txt = "Are you sure you want to delete this Config?"
			if selectedconfig == nzu.CurrentConfig then txt = txt .. " This will reload the server." end
			Derma_Query(txt, "Config deletion confirmation",
				"Delete the Config", function() nzu.RequestDeleteConfig(selectedconfig) end,
				"Cancel"
			):SetSkin("nZombies Unlimited")
		end
	end

	savemeta.DoClick = function()
		if editedconfig and editedconfig.Type == "Local" then applyinfo() nzu.RequestSaveConfigInfo(editedconfig) end
	end

	unload.DoClick = function()
		Derma_Query("Are you sure you want to unload?\nThis will reload the server.", "Config load confirmation",
			"Unload", function()
				if editedconfig and editedconfig.Type == "Unsaved" then
					if editedconfig == configlist:GetSelectedConfig() then doconfigclick() end -- Reset info if it is the one shown
					updateloadedconfig() -- Reset
				return end
				nzu.RequestUnloadConfig()
			end,
			"Cancel"
		):SetSkin("nZombies Unlimited")
	end
	
end, "icon16/disk.png", "Save your Config or load another")