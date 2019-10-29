local headerfont = "Trebuchet24"
local namefont = "Trebuchet24"
local textfont = "Trebuchet18"

local configpaneltall = 60
nzu.AddSpawnmenuTab("Save/Load", "DPanel", function(panel)
	--panel:SetSkin("nZombies Unlimited")
	--panel:SetBackgroundColor(Color(150,150,150))
	local editedconfig
	local editsmade = {}
	
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

	-- The addon panel needs special construction
	local addonarea = editpanel:Add("Panel")
	addonarea:DockMargin(15,0,0,0)
	addonarea:Dock(RIGHT)
	addonarea:SetWide(200)

	-- Top two fields are merged, so we make a new panel to dock them into
	local topfields = editpanel:Add("Panel")
	topfields:Dock(TOP)
	topfields:SetTall(50)
	topfields:DockMargin(0,0,0,5)

	local editfields = {
		{
			Key = "Name",
			Header = "Config Name",
			Placeholder = "Display name...",
			Parent = topfields,
			Dock = FILL
		},

		{
			Key = "WorkshopID",
			Header = "Workshop ID",
			Placeholder = "123456789",
			Parent = addonarea,
			Dock = TOP,
			--Width = 165,
		},


		{
			Key = "Authors",
			Header = "Authors",
			Placeholder = "Author list..."
		},
		{
			Key = "Description",
			Header = "Description",
			Placeholder = "Config description...",
			Dock = FILL
		},
	}

	-- Create the addon field panel
	local addon_panel = addonarea:Add("DPanel")
	addon_panel:Dock(FILL)
	local addon_filter = addon_panel:Add("DTextEntry")
	addon_filter:Dock(BOTTOM)
	addon_filter:SetPlaceholderText("Filter addons ...")
	addon_filter:SetUpdateOnType(true)
	local addon_scroll = addon_panel:Add("DScrollPanel")
	addon_scroll:Dock(FILL)

	addon_panel.List = addon_scroll
	addon_panel.FilterField = addon_filter
	addon_panel.Addons = {}
	addon_panel.RequiredAddons = {}
	addon_panel.Panels = {}

	-- The automated system uses SetEnabled, SetValue, and GetValue, and the callback OnValueChange
	-- We must populate our custom panel with these functions so that they work naturally with the system
	function addon_panel:SetEnabled(b)
		self.FilterField:SetVisible(b)
		self.Enabled = b
		self:Refresh()
		self:Filter(b and self.FilterField:GetValue() or "")
	end

	function addon_panel:SetText(t) -- The table of items enabled, same format as config: {[wsid] = addon title, ...}
		if t == nil or t == "" then t = {} end
		self.RequiredAddons = t

		if self.Enabled then
			for k,v in pairs(self.Panels) do
				v.Checkbox:SetChecked(self.RequiredAddons[k] and true or false)
			end
		else
			self:Filter("") -- Causes rebuild + sorting
		end
	end

	function addon_panel:GetValue()
		return self.RequiredAddons
	end

	-- Refresh what addons are available. This should be invoked whenever the (unfiltered) list's options should be changed
	function addon_panel:Refresh()
		self.Addons = {}
		for k,v in pairs(engine.GetAddons()) do
			if v.downloaded and v.wsid and v.mounted then
				self.Addons[v.wsid] = v.title
			end
		end
	end

	function addon_panel:Filter(str)
		self.List:Clear()
		self.Panels = {}

		local filtered
		if not str or str == "" then
			filtered = self.Enabled and self.Addons or self.RequiredAddons
		else
			filtered = {}
			for k,v in pairs(self.Enabled and self.Addons or self.RequiredAddons) do
				if string.find(v:lower(), str:lower()) then
					filtered[k] = v
				end
			end
		end

		if self.Enabled then
			-- Enabled: Checkboxes, no color on URL labels
			for k,v in SortedPairsByValue(filtered) do
				local p = self.List:Add("Panel")
				p:DockPadding(2,2,2,2)

				local c = p:Add("DCheckBox")
				c:Dock(LEFT)
				c:DockMargin(0,0,5,0)
				c:SetChecked(self.RequiredAddons[k] and true or false)
				function c:PerformLayout()
					self:SetWide(self:GetTall())
				end

				function c.OnChange(s,b)
					if b then
						self.RequiredAddons[k] = v
					else
						self.RequiredAddons[k] = nil
					end
					self:OnValueChange(self.RequiredAddons) -- Fire the callback!
				end
				
				local l = p:Add("DLabelURL")
				l:SetText(v)
				l:SetTextColor(Color(200,200,200))
				l:Dock(FILL)
				l:SetContentAlignment(4)
				l:SetURL("https://steamcommunity.com/sharedfiles/filedetails/?id="..k)
				
				self.List:Add(p)
				p:Dock(TOP)
				p:SetTall(24)

				self.Panels[k] = p
				p.Checkbox = c
			end
		else
			-- Disabled: No checkboxes, URL label colors
			for k,v in SortedPairsByValue(filtered) do
				local l = self.List:Add("DButton")
				l:SetText(v)
				l:SetContentAlignment(5)
				l.DoClick = function() gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id="..k) end
				l:SetTextColor(steamworks.ShouldMountAddon(k) and Color(0,255,0) or Color(255,0,0))
				
				self.List:Add(l)
				l:Dock(TOP)

				self.Panels[k] = l
			end
		end
	end

	addon_panel.Enabled = true
	addon_panel:Refresh()
	addon_panel:Filter()

	addon_filter.OnValueChange = function(s,str)
		addon_panel:Filter(str)
	end

	-- Add it to the constructor!
	table.insert(editfields, {
		Key = "RequiredAddons",
		Header = "Addons",
		Parent = addonarea,
		Panel = addon_panel,
		Dock = FILL,
	})

	-- Whenever a field is edited, store its results in another table
	local editpanels = {}
	local function valuechange(s,v)
		editsmade[s.Key] = v
		editpanels[s.Key].Revert:SetEnabled(true)

		-- Modify the loaded panel
		local c = loadedcfg.Config
		if not c or c.Type ~= "Unsaved" then
			loadedcfg:SetConfig({
				Name = editsmade.Name or editedconfig.Name,
				Map = editedconfig.Map,
				Type = "Unsaved",
				Codename = editedconfig.Codename
			})
		elseif s.Key == "Name" then
			loadedcfg.Config.Name = v
			loadedcfg:SetName(v)
		end
	end
	local function revertfunc(s)
		editsmade[s.Key] = nil
		if editedconfig then editpanels[s.Key].Contents:SetText(editedconfig[s.Key]) end
		s:SetEnabled(false)

		if table.IsEmpty(editsmade) then
			loadedcfg:SetConfig(editedconfig)
		end
	end

	-- Build the panels!
	local placeholdcol = Color(75,75,75)
	for k,v in pairs(editfields) do
		local parent = v.Parent or editpanel
		local p = parent:Add("Panel")

		local header = p:Add("Panel")
		header:Dock(TOP)
		header:DockMargin(0,0,0,3)

		local lbl = header:Add("DLabel")
		lbl:Dock(LEFT)
		lbl:SetFont(headerfont)
		lbl:SetText(v.Header)
		lbl:SizeToContents()
		header:SetTall(lbl:GetTall())

		local revert = header:Add("DButton")
		revert:SetText("Revert")
		revert:Dock(RIGHT)
		revert:SetWide(50)
		revert:DockMargin(0,3,0,0)
		revert:SetEnabled(false)
		revert.Key = v.Key
		revert.DoClick = revertfunc

		local field = v.Panel
		if not IsValid(field) then
			field = p:Add("DTextEntry")
			field:Dock(FILL)
			field:SetFont(namefont)
			field:SetPlaceholderText(v.Placeholder)
			field:SetPlaceholderColor(placeholdcol)
			field:SetUpdateOnType(true)
		else
			field:SetParent(p)
		end

		p:Dock(v.Dock or TOP)
		if v.Width then p:SetWide(v.Width) end
		p:SetTall(v.Height or 50)

		-- Now implement their functionality!
		field.Key = v.Key
		field.OnValueChange = valuechange

		editpanels[v.Key] = {Panel = p, Contents = field, Header = header, Revert = revert}
	end

	editpanels.Authors.Panel:DockMargin(0,0,0,5)
	editpanels.Description.Contents:SetMultiline(true)
	editpanels.Description.Contents:SetFont(textfont)
	editpanels.Description.Panel:DockMargin(0,0,0,0)
	editpanels.WorkshopID.Panel:DockMargin(0,0,0,5)

	-- Add the additional controls
	local mapname = editpanels.Name.Header:Add("DLabel")
	mapname:SetText("File:          || Map: ")
	mapname:SetFont(textfont)
	mapname:Dock(FILL)
	mapname:DockMargin(10,0,0,0)
	mapname:SizeToContents()
	mapname:SetContentAlignment(1)

	local widinfo = editpanels.WorkshopID.Header:Add("DImage")
	widinfo:SetImage("icon16/information.png")
	widinfo:Dock(LEFT)
	widinfo:DockMargin(5,5,0,5)
	widinfo:SetMouseInputEnabled(true)
	widinfo:SetTooltip("Enter the numerical ID of this Config's Workshop addon after it has been uploaded.\nThis allows players to view your Config's Workshop page from in-game.")
	function widinfo:PerformLayout()
		self:SetWide(self:GetTall())
	end

	local authorstoplayers = editpanels.Authors.Header:Add("DButton")
	authorstoplayers:SetText("Set to current players")
	authorstoplayers:Dock(LEFT)
	authorstoplayers:SetWide(130)
	authorstoplayers:DockMargin(10,2,0,2)
	-- Hook it in so it disables with the text field
	local oldenable = editpanels.Authors.Contents.SetEnabled
	function editpanels.Authors.Contents:SetEnabled(b)
		oldenable(self, b)
		authorstoplayers:SetEnabled(b)
	end
	-- Add its function
	function authorstoplayers:DoClick()
		local str = ""
		for k,v in pairs(player.GetHumans()) do
			str = str .. v:Nick() .. ", "
		end
		str = string.sub(str, 0, #str - 2)
		editpanels.Authors.Contents:SetValue(str)
	end

	-- The bottom save/load controls
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

	-- Control selecting configs
	local function displayconfig(cfg)
		infopanel.Config = cfg
		if not cfg then infopanel:SetVisible(false) return end
		infopanel:SetVisible(true)

		local iseditedconfig = infopanel.IsEditedConfig
		for k,v in pairs(editpanels) do
			v.Contents:SetText(iseditedconfig and editsmade[k] or cfg[k] or "")
		end
		img:SetImage(nzu.GetConfigThumbnail(cfg) or "vgui/black.png")
		mapname:SetText("File: " .. cfg.Codename .. " || Map: "..cfg.Map)

		-- Editing
		local canedit = iseditedconfig and nzu.IsAdmin(LocalPlayer()) and (cfg.Type == "Local" or cfg.Type == "Unsaved")
		for k,v in pairs(editpanels) do
			v.Contents:SetEnabled(canedit)
		end

		save:SetEnabled(canedit)
		reload:SetText(canedit and "Reload last saved version" or cfg == nzu.CurrentConfig and "Reload Config" or "Load Config")
		reload:SetEnabled(canedit or nzu.IsAdmin(LocalPlayer()))
		savemeta:SetEnabled(canedit)
		delete:SetEnabled(canedit or (cfg.Type == "Local" and nzu.IsAdmin(LocalPlayer())))
		playbutton:SetText(canedit and "Save and Play" or "Load and Play")

	end
	configlist.OnConfigClicked = function(s,cfg,pnl)
		infopanel.IsEditedConfig = false -- Clicking from the list means it's a non-edited one
		displayconfig(cfg)
		loadedcfg:SetSelected(false)
	end

	-- Update through hook if the config updated is the currently viewed one
	hook.Add("nzu_ConfigInfoSaved", infopanel, function(self, config)
		if self.Config == config then
			displayconfig(config) -- Update it! :D
		end
		if editedconfig and config.Codename == editedconfig.Codename and not table.IsEmpty(editsmade) and not editsmade.Name then
			loadedcfg:SetName(config.Name)
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
		s:SetSelected(true)
		infopanel.IsEditedConfig = true
		displayconfig(editedconfig)
		configlist:SelectConfig()
	end

	local function applyinfo()
		for k,v in pairs(editsmade) do
			editedconfig[k] = v
			editpanels[k].Revert:SetEnabled(false)
		end
		editsmade = {}
		loadedcfg:SetConfig(editedconfig)
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