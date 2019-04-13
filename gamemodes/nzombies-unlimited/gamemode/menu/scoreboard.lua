local columns = {
	{Text = translate.Get("ping"), Get = function(ply) return ply:Ping() end, Order = 0},
	--{Text = "Headshots", Get = function(ply) return ply:Ping() end, Order = 10},
	{Text = translate.Get("revives"), Get = function(ply) return ply:GetNumRevives() end, Order = 20},
	{Text = translate.Get("downs"), Get = function(ply) return ply:GetNumDowns() end, Order = 30},
	{Text = translate.Get("kills"), Get = function(ply) return ply:Frags() end, Order = 40},
	{Text = translate.Get("score"), Get = function(ply) return ply:GetPoints() end, Width = 200, Order = 50},
}

--[[
local columns = {}
function nzu.AddScoreboardStat(name, tbl)
	columns[name] = tbl
end
nzu.AddScoreboardStat("Ping", {
	Get = function(ply) return ply:Ping() end,
	Order = 0,
})]]

local lineheight = 50
local statwidth = 100

local color_base = Color(0,0,0,240)
local color_alt = Color(0,30,40,240)

local font = "nzu_Font_Points_PointsSmall"
local textcol = Color(255,255,255)
local textcol_highlight = Color(255,255,50)

local matblur = Material("pp/blurscreen")
local function barpaint(self,w,h)
	surface.SetMaterial(matblur)
	surface.SetDrawColor(self.m_bgColor)

	local x,y = self:LocalToScreen(0,0)
	for i = 0.33,1,0.33 do
		matblur:SetFloat("$blur", 5*i)
		matblur:Recompute()
		if render then render.UpdateScreenEffectTexture() end
		surface.DrawTexturedRect(-x,-y,ScrW(),ScrH())
	end

	self:DrawFilledRect()
end

local PLAYERLINE = {
	Init = function(self)
		self.Labels = {}
		self.Values = {}
		for k,v in pairs(columns) do
			local p = self:Add("DPanel")
			p:Dock(RIGHT)
			p:SetZPos(v.Order or 0)
			p:SetWide(v.Width or statwidth)
			p:SetBackgroundColor(k%2 == 0 and color_base or color_alt)
			--p:SetBackgroundColor(color_base)
			p.Paint = barpaint

			local lbl = p:Add("DLabel")
			lbl:SetWide(statwidth)
			lbl:SetFont(font)
			lbl:Dock(FILL)
			lbl:SetContentAlignment(5)

			self.Labels[k] = lbl
		end

		local main = self:Add("DPanel")
		main:Dock(FILL)
		main:SetBackgroundColor(color_base)
		main.Paint = barpaint

		self.PlayerAvatar = main:Add("nzu_PlayerAvatar")
		self.PlayerAvatar:Dock(LEFT)
		self.PlayerAvatar:DockMargin(5,5,5,5)
		self.PlayerAvatar:SetWide(lineheight - 10)

		self.Name = main:Add("DLabel")
		self.Name:SetFont(font)
		self.Name:Dock(FILL)

		local but = self:Add("DButton")
		but:Dock(FILL)
		but:SetText("")
		but.Paint = function() end
		but.DoClick = function()
			self.Player:ShowProfile()
		end
	end,
	Setup = function(self, ply)
		self.Player = ply
		self.PlayerAvatar:SetPlayer(ply)

		local col = ply == LocalPlayer() and textcol_highlight or textcol
		for k,v in pairs(self.Labels) do
			v:SetTextColor(col)
		end
		self.Name:SetTextColor(col)

		self:Think()
	end,
	Think = function(self)
		if not IsValid(self.Player) or self.Player:IsUnspawned() then
			self:SetZPos(99999)
			self:Remove()
		return end

		for k,v in pairs(self.Labels) do
			if self.Values[k] == nil or self.Values[k] ~= columns[k].Get(self.Player) then
				self.Values[k] = columns[k].Get(self.Player)
				v:SetText(self.Values[k])
			end
		end

		if self.PName == nil or self.PName ~= self.Player:Nick() then
			self.PName = self.Player:Nick()
			self.Name:SetText(self.PName)
		end
	end,
}
PLAYERLINE = vgui.RegisterTable(PLAYERLINE, "Panel")

local SCOREBOARD = {
	Init = function(self)
		local server = self:Add("DLabel")
		server:Dock(TOP)
		server:SetText(GetHostName())
		server:SetFont("nzu_Font_Bloody_Large")
		server:SetTextColor(Color(255,0,0))
		server:SetContentAlignment(5)
		server:SizeToContentsY()
		server:DockMargin(0,0,0,5)

		local header = self:Add("DPanel")
		header:Dock(TOP)
		header:SetHeight(lineheight)
		header:DockMargin(0,0,0,2)
		for k,v in pairs(columns) do
			local lbl = header:Add("DLabel")
			lbl:SetText(v.Text)
			lbl:SetWide(v.Width or statwidth)
			lbl:Dock(RIGHT)
			lbl:SetFont(font)
			lbl:SetContentAlignment(5)
			lbl:SetZPos(v.Order or 0)
		end
		header:SetBackgroundColor(color_base)
		header.Paint = barpaint

		self.ConfigName = header:Add("DLabel")
		self.ConfigName:Dock(FILL)
		self.ConfigName:DockMargin(5,5,5,5)
		self.ConfigName:SetFont(font)
		self.ConfigName:SetText(translate.Get("no_config"))

		self.Lines = self:Add("DScrollPanel")
		self.Lines:Dock(FILL)
	end,
	PerformLayout = function(self)
		self:SetSize(ScrW()/2, ScrH() - 200)
		self:SetPos(ScrW()/4, 100)
	end,
	Think = function(self)
		for k,v in pairs(player.GetAll()) do
			if not IsValid(v.ScoreboardLine) and not v:IsUnspawned() then
				v.ScoreboardLine = vgui.CreateFromTable(PLAYERLINE, self.Lines)
				v.ScoreboardLine:Dock(TOP)
				v.ScoreboardLine:SetTall(lineheight)
				v.ScoreboardLine:Setup(v)
				self.Lines:AddItem(v.ScoreboardLine)
			end
		end

		if self.LoadedConfig ~= nzu.CurrentConfig then
			self.LoadedConfig = nzu.CurrentConfig
			self.ConfigName:SetText(nzu.CurrentConfig and nzu.CurrentConfig.Name or "No Config Loaded")
		end
	end,
}
SCOREBOARD = vgui.RegisterTable(SCOREBOARD, "EditablePanel")

local scoreboard
function GM:ScoreboardShow()
	if not IsValid(scoreboard) then
		scoreboard = vgui.CreateFromTable(SCOREBOARD)
	end

	scoreboard:Show()
	scoreboard:MakePopup()
	scoreboard:SetKeyboardInputEnabled(false)
end

function GM:ScoreboardHide()
	if IsValid(scoreboard) then
		scoreboard:Hide()
		scoreboard:Remove()
	end
end