local headerfont = "Trebuchet24"
local namefont = "Trebuchet24"
local textfont = "Trebuchet18"

local sortorder = {
	Official = 1,
	Local = 2,
	Workshop = 3
}

local configpaneltall = 60
nzu.AddSpawnmenuTab("Save/Load", "DPanel", function(panel)
	--panel:SetSkin("nZombies Unlimited")
	--panel:SetBackgroundColor(Color(150,150,150))
	local selectedconfig
	
	local configpanel = panel:Add("DPanel")
	configpanel:SetWidth(400)
	--configpanel:SetBackgroundColor(Color(40,30,30))
	configpanel:Dock(LEFT)

	local infopanel = panel:Add("DPanel")
	infopanel:SetBackgroundColor(Color(50,40,40))
	infopanel:Dock(FILL)
	infopanel:DockPadding(30,30,30,30)

	-- Top of the config scroll list, we find info about currently loaded configs or new configs
	local curpanel = configpanel:Add("DPanel")
	curpanel:Dock(TOP)
	curpanel:SetTall(70 + configpaneltall)
	curpanel.m_bDrawCorners = true
	curpanel:DockMargin(5,5,0,25)
	local curloaded = curpanel:Add("DLabel")
	curloaded:SetText("Currently loaded:")
	curloaded:SetFont(headerfont)
	curloaded:DockMargin(5,5,5,5)
	curloaded:Dock(TOP)
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
	local noloaded = loadedpnl:Add("DLabel")
	noloaded:SetText("No Config currently loaded.")
	noloaded:Dock(FILL)
	noloaded:SetContentAlignment(5)
	noloaded:SetFont(textfont)

	local createbutton = curpanel:Add("DButton")
	createbutton:Dock(FILL)
	createbutton:SetText("Create new Config ...")
	createbutton:DockMargin(10,7,10,7)

	hook.Add("nzu_CurrentConfigChanged", curpanel, function(s, config)
		loadedcfg:SetConfig(config)
		if config then
			loadedcfg:SetVisible(true)
			createbutton:SetText("Create new local copy ...")
		else
			loadedcfg:SetVisible(false)
			createbutton:SetText("Create new Config ...")
		end
	end)

	local configscroll = configpanel:Add("DScrollPanel")
	configscroll:Dock(FILL)
	configscroll:DockMargin(5,0,0,5)
	local configlist = configscroll:Add("DListLayout")
	configlist:Dock(FILL)
	
	
	
	local img = infopanel:Add("DImage")
	img:SetImage("maps/thumb/gm_construct.png")
	img:Dock(TOP)
	img:DockMargin(0,0,0,15)
	function img:PerformLayout()
		local w = self:GetWide()
		self:SetTall(w/16 * 9)
	end
	
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
	widinfo:SetTooltip("Hi")
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
	addonscroll:SetBackgroundColor(Color(50,50,50))
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
				self.Addons[v.wsid] = p
			end
		end
	end
	function addonlist:Recheck()
		for k,v in pairs(self.Addons) do
			v.CheckBox:SetChecked(selected and selected.RequiredAddons[k] or false)
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
	mapname:SetText("File: nzu_breakout || Map: ttt_kosovos")
	mapname:SetFont(textfont)
	mapname:Dock(LEFT)
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
	
	local saveload = infopanel:Add("Panel")
	saveload:DockMargin(0,30,0,0)
	saveload:SetTall(30)
	saveload:Dock(BOTTOM)
	
	local reload = saveload:Add("DButton")
	reload:SetText("Reload last saved version")
	local save = saveload:Add("DButton")
	save:SetText("Save Config")
	
	function saveload:PerformLayout()
		local w = self:GetWide()/2 + 15
		reload:StretchToParent(0,0,w,0)
		save:StretchToParent(w,0,0,0)
	end

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
		if IsValid(selectedconfig) then selectedconfig:SetBackgroundColor(Color(0,0,0)) end
		selectedconfig = pnl
		selectedconfig:SetBackgroundColor(Color(0,150,255))
		infopanel:SetVisible(true)

		local cfg = pnl.Config
		configname:SetText(cfg.Name)
		authors:SetText(cfg.Authors)
		desc:SetText(cfg.Description)
		mapname:SetText("File: " .. cfg.Codename .. " || Map: "..cfg.Map)
		widentry:SetText(cfg.WorkshopID or "")

		-- Addon list
		if cfg == nzu.CurrentConfig then
			addonscroll:SetVisible(true)
			addonlist2_Scroll:SetVisible(false)

			save:SetEnabled(true)
			reload:SetText("Reload last saved version")
		else
			addonscroll:SetVisible(false)
			addonlist2_Scroll:SetVisible(true)

			save:SetEnabled(false)
			reload:SetText("Load Config")

			addonlist2:Clear()
			for k,v in pairs(cfg.RequiredAddons) do
				local lbl = addonlist2:Add("DLabelURL")
				lbl:SetText(v)
				lbl:SetURL("https://steamcommunity.com/sharedfiles/filedetails/?id="..k)
				lbl:SetTextColor(steamworks.ShouldMountAddon(k) and Color(0,255,0) or Color(255,0,0))
			end
		end
	end

	-- Create new config button
	-- REDO THIS PART. It's not really robust or clean, probably better to our own panel
	function createbutton:DoClick()
		local pnl,txt,lbl
		local function dotest(text)
			if nzu.ConfigExists(text, "Official") then
				lbl:SetText("A Local config by that name already exists.")
				txt.HighlightRed = 255
				lbl.HighlightRed = 255
				return false
			end

			return true
		end
		pnl = Derma_StringRequest("Enter new Config Codename",
			"Enter Config folder name. Must be a valid directory name.",
			"",
			nil,nil,"Create Config"
		)
		txt = pnl:GetChild(4):GetChild(1)
		lbl = pnl:GetChild(4):GetChild(0)

		pnl:GetChild(5):GetChild(0).DoClick = function(s) if dotest(txt:GetValue()) then pnl:Close() end end
		txt.OnEnter = function(s) if dotest(s:GetValue()) then pnl:Close() end end

		local function errorlight(s,w,h)
			if s.HighlightRed then
				surface.SetDrawColor(255,0,0,s.HighlightRed)
				local x2,y2 = s:GetSize()
				surface.DrawRect(-50, -50, x2+50, y2+50)
				s.HighlightRed = s.HighlightRed - FrameTime() * 100
				if s.HighlightRed <= 0 then
					s.HighlightRed = nil
				end
			end
		end
		txt.PaintOver = errorlight
		lbl.PaintOver = errorlight
	end

	-- Populate configs
	local function addconfig(_, config)
		local pnl = configlist:Add("nzu_ConfigPanel")
		pnl:SetConfig(config)
		pnl:SetTall(configpaneltall)
		pnl:SetZPos((config.Map == game.GetMap() and 0 or 5) + (sortorder[config.Type]))
		pnl.DoClick = doconfigclick
	end
	local configs = nzu.GetConfigs()
	if configs then
		for k,v in pairs(configs) do
			for k2,v2 in pairs(v) do
				for i = 1,20 do addconfig(nil, v2) end
			end
		end
	end
	hook.Add("nzu_ConfigInfoUpdated", configpanel, addconfig)
	loadedcfg.DoClick = doconfigclick

	
end, "icon16/disk.png", "Save your Config or load another")