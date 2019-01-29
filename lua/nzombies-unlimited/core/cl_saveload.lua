local headerfont = "Trebuchet24"
local namefont = "Trebuchet24"
local textfont = "Trebuchet18"

local sortorder = {
	Official = 1,
	Local = 2,
	Workshop = 3
}

nzu.AddSpawnmenuTab("Save/Load", "DPanel", function(panel)
	--panel:SetSkin("nZombies Unlimited")
	--panel:SetBackgroundColor(Color(150,150,150))
	
	local configpanel = panel:Add("DPanel")
	configpanel:SetWidth(400)
	--configpanel:SetBackgroundColor(Color(40,30,30))
	configpanel:Dock(LEFT)

	local configscroll = configpanel:Add("DScrollPanel")
	configscroll:Dock(FILL)
	local configlist = configscroll:Add("DListLayout")
	configlist:Dock(FILL)
	
	-- Populate configs
	local function addconfig(_, config)
		local pnl = configlist:Add("nzu_ConfigPanel")
		pnl:SetConfig(config)
		pnl:SetTall(50)
		pnl:SetZPos((config.Map == game.GetMap() and 0 or 5) + (sortorder[config.Type]))
	end
	local configs = nzu.GetConfigs()
	if configs then
		for k,v in pairs(configs) do
			for k2,v2 in pairs(v) do
				addconfig(nil, v2)
			end
		end
	end
	hook.Add("nzu_ConfigInfoUpdated", configpanel, addconfig)
	
	local infopanel = panel:Add("DPanel")
	infopanel:SetBackgroundColor(Color(50,40,40))
	infopanel:Dock(FILL)
	infopanel:DockPadding(30,30,30,30)
	
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
				c:SetChecked(selected and selected.Addons[v.wsid] or false)
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
			v.CheckBox:SetChecked(selected and selected.Addons[k] or false)
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
	
end, "icon16/disk.png", "Save your Config or load another")