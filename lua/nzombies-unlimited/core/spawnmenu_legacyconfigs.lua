
local modules = {
	["ZedSpawns"] = {
		Label = "Zombie Spawnpoints",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("nzu_spawnpoint")
				e:SetPos(v.pos)
				e:SetSpawnpointType("zombie")
				e:Spawn()

				if v.link then e:AddRoom(v.link) end
			end
		end
	},
	["ZedSpecialSpawns"] = {
		Label = "Special Zombie Spawnpoints",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("nzu_spawnpoint")
				e:SetPos(v.pos)
				e:SetSpawnpointType("special")
				e:Spawn()

				if v.link then e:AddRoom(v.link) end
			end
		end
	},
	["PlayerSpawns"] = {
		Label = "Player Spawnpoints",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("nzu_spawnpoint")
				e:SetPos(v.pos)
				e:SetSpawnpointType("player")
				e:Spawn()
			end
		end
	},

	["WallBuys"] = {
		Label = "Wall Buys",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("nzu_wallbuy")

				local pos,ang = LocalToWorld(Vector(0,0,0), v.flipped and Angle(0,90,0) or Angle(0,0,0), v.pos, v.angle)
				e:SetPos(pos)
				e:SetAngles(ang)

				e:SetWeaponClass(v.wep)
				e:SetPrice(v.price)

				e:Spawn()
			end
		end
	},

	["BuyablePropSpawns"] = {
		Label = "Props",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("prop_physics")
				e:SetPos(v.pos)
				e:SetAngles(v.angle)
				e:SetModel(v.model)
				e:Spawn()
				local l = e:GetPhysicsObject()
				if IsValid(l) then
					l:EnableMotion(false)
					l:Sleep()
				end

				-- Load the door data if there is any
				if v.flags then
					local tbl = string.Explode(",", v.flags)
					local t = {}
					for k,v in pairs(tbl) do
						local id,val = string.match(v, "(.+)=(.+)")
						if id and val then
							t[id] = val
						end
					end

					if t.price and t.elec then
						if tobool(t.buyable) then
							local data = {
								Price = t.price,
								Electricity = tobool(t.elec), -- Should work right?
							}

							if t.link then
								data.Group = t.link
								data.Rooms = {t.link} -- Emulates old behavior by rooms and links being the same
							end
							e:CreateDoor(data)
						else
							-- TODO: Support locking doors when that tool exists
						end
					end
				end
			end
		end
	},

	["PropEffects"] = {
		Label = "Effect Props",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("prop_effect")
				e:SetPos(v.pos)
				e:SetAngles(v.angle)
				e:SetModel(v.model) -- This work directly? Or does it have to be e.AttachedEntity?
				e:Spawn()

				local l = e:GetPhysicsObject()
				if IsValid(l) then
					l:EnableMotion(false)
					l:Sleep()
				end
			end
		end
	},

	["EasterEggs"] = {
		Label = "Music Easter Eggs",
		-- TODO: Add Load function when music easter eggs are implemented
	},

	["ElecSpawns"] = {
		Label = "Electricity Switch",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("nzu_electricityswitch")
				e:SetPos(v.pos)
				e:SetAngles(v.angle)
				e:Spawn()
			end
		end,
	},

	["BlockSpawns"] = {
		Label = "Invisible Plates",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("nzu_prop_playerclip")
				e:SetPos(v.pos)
				e:SetAngles(v.angle)
				e:SetModel(v.model)
				e:Spawn()
			end
		end,
	},

	["RandomBoxSpawns"] = {
		Label = "Mystery Box Spawnpoints",
		-- TODO: Add when Mystery Box is implemented
	},

	["PerkMachineSpawns"] = {
		Label = "Perk Machines",
		-- TODO: Add when Perks is implemented
	},

	["DoorSetup"] = {
		Label = "Doors",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.GetMapCreatedEntity(k)
				if IsValid(e) then
					local tbl = string.Explode(",", v.flags)
					local t = {}
					for k,v in pairs(tbl) do
						local id,val = string.match(v, "(.+)=(.+)")
						if id and val then
							t[id] = val
						end
					end

					if t.price and t.elec then
						if tobool(t.buyable) then
							local data = {
								Price = t.price,
								Electricity = tobool(t.elec),
							}

							if t.link then
								data.Group = t.link
								data.Rooms = {t.link}
							end
							e:CreateDoor(data)
						else
							-- TODO: Support locking doors when that tool exists
						end
					end
				end
			end
		end
	},

	["BreakEntry"] = {
		Label = "Barricades",
		Load = function(data)
			for k,v in pairs(data) do
				local e = ents.Create("nzu_barricade")

				local pos,ang = LocalToWorld(Vector(0,0,-50), Angle(0,0,0), v.pos, v.angle)

				e:SetPos(pos)
				e:SetAngles(ang)
				e:SetTriggerVault(v.jump)
				e:SetMaxPlanks(tobool(v.planks) and 6 or 0)
				e:Spawn()
			end
		end
	},

	["InvisWalls"] = {
		Label = "Invisible Walls",
		-- TODO: Will we ever implement these?
	},

	["DamageWalls"] = {
		Label = "Damage Invisible Walls",
		-- TODO: Will we ever implement these either?
	},

	["NavTable"] = {
		Label = "Nav Locks (Note: Will not be correct if Navmesh is not identical)",
		Load = function(data)
			for k,v in pairs(data) do
				if v.locked or v.link then
					local a = navmesh.GetNavAreaByID(k)
					if IsValid(a) then
						nzu.LockNavArea(a, v.link)
					else
						print("nzu_legacy: Attempted to apply Nav Lock to non-existent Nav Area: "..k)
					end
				end
			end
		end
	},

	["RemoveProps"] = {
		Label = "Map Prop Removals",
		Load = function(data)
			for k,v in pairs(data) do
				SafeRemoveEntity(ents.GetMapCreatedEntity(k))
			end
		end,
	},

	["MapSettings"] = {
		Label = "Map Settings (Start weapon and Points)", -- TODO: Add support for Special and Boss rounds when implemented
		Load = function(data)
			local ext = nzu.GetExtension("Core")
			if data.startpoints then ext.Settings("StartPoints", data.startpoints) end
			if data.startwep then ext.Settings("StartWeapon", data.startwep) end
		end,
	},

	["MapSettingsRound"] = {
		Label = "Map Settings (Special Round & Bosses)",
		-- TODO: Remove when support for rounds and bosses are added to main MapSettings
	},

	["MapSettingsBox"] = {
		Label = "Map Settings (Mystery Box Weapons)",
		-- TODO: Remove when support box weapons are added to main MapSettings
	},

	["PackAPunch"] = {
		Label = "Pack-a-Punch",
		-- TODO: Remove when support for perks are added as pap just goes under that
	},
}

if SERVER then
	util.AddNetworkString("nzu_legacyconfig")
	net.Receive("nzu_legacyconfig", function(len, ply)
		if not ply:IsListenServerHost() then return end

		-- It's kinda intention it doesn't check against the map
		-- if you REALLY wanted, you CAN load other maps' configs

		local name = net.ReadString()
		local dir = net.ReadString()

		local path
		if dir == "Local" then path = "data/nz/"..name
		elseif dir == "Workshop" then path = "lua/nz/"..name
		else path = "gamemodes/nzombies/officialconfigs/"..name end

		local data = file.Read(path, "GAME")
		if data then
			local tbl = util.JSONToTable(data)
			if tbl then
				for k,v in pairs(tbl) do
					if modules[k] and modules[k].Load then
						modules[k].Load(v)
					end
				end
			end
		end
	end)
	return
end

--[[-------------------------------------------------------------------------
Project Information
---------------------------------------------------------------------------]]
local projectlink = "https://github.com/Zet0rz/nZombies-Unlimited/projects/5"
local basevers = "Version 1.0: Barebones"
local basevers2 = {
	"Sandbox System",
	"Main Gamemode",
	"Round System",
	"HUD",
	"Revive System",
	"Stamina System",
	"Weapon Slot System",
	"Mismatch System",
	"Zombie NPCs",
	"Zombie Models and Sounds",
	"Barricades",
	"Wall Buys",
	"Doors & Rooms Systems",
	"Nav Locks",
	"Nav Editor",
	"[Config] Permafrost 1.0",
	"Legacy Config Loader",
}

local projects = {
	"https://github.com/Zet0rz/nZombies-Unlimited/projects/5",
}

--[[-------------------------------------------------------------------------
Panel
---------------------------------------------------------------------------]]

surface.CreateFont("nzu_Font_Bloody_Medium", {
	font = "DK Umbilical Noose",
	size = 36,
	weight = 500,
	antialias = true,
})

for k,v in pairs(modules) do
	if v.Load then v.Load = true end -- Discard the functions clientside
end

nzu.AddSpawnmenuTab("Version/Legacy", "DPanel", function(panel)
	local left = vgui.Create("DPanel", panel)
	left:Dock(LEFT)
	left:SetWide(400)

	local old = left:Add("DLabel")
	old:SetText("Legacy Configs")
	old:Dock(TOP)
	old:SetContentAlignment(5)
	old:SetFont("Trebuchet24")
	old:DockMargin(5,5,5,5)

	local note = left:Add("DLabel")
	note:SetText("Note: Only works if you are in Singleplayer or you are the server host.")
	note:Dock(TOP)
	note:SetContentAlignment(5)
	note:DockMargin(5,-5,5,5)

	local refresh = left:Add("DButton")
	refresh:Dock(TOP)
	refresh:SetText("Refresh Legacy Configs")
	refresh:DockMargin(50,15,50,5)

	local scroll = left:Add("nzu_ConfigList")
	scroll:Dock(FILL)
	scroll:DockMargin(0,10,0,10)
	scroll:SetPaintBackground(true)
	scroll.m_bDrawCorners = true
	scroll:SetSelectable(true)

	local load = left:Add("DButton")
	load:Dock(BOTTOM)
	load:SetText("No Config selected")
	load:SetEnabled(false)
	load:SetTall(40)
	load:DockMargin(50,0,50,10)

	refresh.DoClick = function()
		scroll:Clear()

		local configs = {
			["Local"] = file.Find("nz/nz_*", "DATA"),
			["Workshop"] = file.Find("nz/nz_*", "LUA"),
			["Official"] = file.Find("gamemodes/nzombies/officialconfigs/*", "GAME")
		}

		for k,v in pairs(configs) do
			for k2,v2 in pairs(v) do
				local map,name = string.match(v2, "nz_([^;]+);([^;]+)")
				if map and name then

					local cfg = scroll:AddConfig({
						Name = name,
						Codename = "nz_"..map..";"..name,
						Map = map,
						Type = k,
						File = v2
					})

					-- This is how the old nZombies showed the thumbnail
					local icon = "nzmapicons/nz_"..map..";"..name..".png"
					if Material(icon):IsError() then icon = "maps/thumb/"..map..".png" end
					if Material(icon):IsError() then icon = "maps/"..map..".png" end
					if Material(icon):IsError() then icon = "noicon.png" end

					cfg.Thumbnail:SetWide(cfg:GetTall() - 10) -- Make it square
					cfg.PerformLayout = function(s,w,h) -- Make the thumbnail not auto-fill 16:9 size
						s.Button:SetSize(w,h)
					end
					cfg.Thumbnail:SetImage(icon)
				end
			end
		end
	end

	if not nzu.IsAdmin(LocalPlayer()) then
		refresh:SetText("Only Admins can load Legacy Configs.")
		refresh:SetEnabled(false)
	end

	scroll.OnConfigSelected = function(s,c,p)
		if c.Map == game.GetMap() then
			load:SetEnabled(true)
			load:SetText("Load")
		else
			load:SetEnabled(false)
			load:SetText("Config is of a different map")
		end
	end

	load.DoClick = function()
		local cfg = scroll:GetSelectedConfig()
		if cfg and cfg.Map == game.GetMap() then
			net.Start("nzu_legacyconfig")
				net.WriteString(cfg.File)
				net.WriteString(cfg.Type)
			net.SendToServer()
		end
	end

	--[[-------------------------------------------------------------------------
	The Right side, starting bottom discord promo
	---------------------------------------------------------------------------]]
	local dholder = vgui.Create("Panel", panel)
	dholder:Dock(BOTTOM)
	dholder:SetTall(75)
	dholder:DockMargin(0,20,0,20)
	local disc = dholder:Add("DImageButton")
	disc:SetImage("nzombies-unlimited/menu/discord-promo.png")
	disc:SetSize(600,75)

	function dholder:PerformLayout(w,h)
		disc:SetPos(w/2 - 300, 0)
	end

	local link = "https://discord.gg/eJpVSqm"
	disc.DoClick = function()
		local frame = vgui.Create("DFrame")
		frame:SetSkin("nZombies Unlimited")
		frame:SetBackgroundBlur(true)
		frame:SetTitle("Discord Link")
		frame:SetDeleteOnClose(true)
		frame:ShowCloseButton(true)
		frame:SetSize(300, 120)

		local lbl = frame:Add("DLabel")
		lbl:SetText("Click to copy to clipboard")
		lbl:Dock(TOP)
		lbl:SetContentAlignment(5)

		local txt = frame:Add("DButton")
		txt:SetText(link)
		txt:Dock(TOP)
		txt:SetContentAlignment(5)
		txt.DoClick = function(s)
			SetClipboardText(link)
			lbl:SetText("Copied!")
			lbl:SetTextColor(Color(0,255,0))
			s:KillFocus()
		end
		local sk = txt:GetSkin()
		txt.Paint = function(s,w,h) sk.tex.TextBox( 0, 0, w, h ) end

		local but = frame:Add("DButton")
		but:SetText("Open in Steam Overlay")
		but:Dock(BOTTOM)
		but:SetTall(25)
		but:DockMargin(30,0,30,0)
		but.DoClick = function()
			gui.OpenURL(link)
			frame:Close()
		end

		frame:MakePopup()
		frame:Center()
		frame:SetMouseInputEnabled(true)
		frame:DoModal()
	end


	--[[-------------------------------------------------------------------------
	Middle Development
	---------------------------------------------------------------------------]]
	local bot = vgui.Create("Panel", panel)
	bot:Dock(FILL)

	local dev = bot:Add("DLabel")
	dev:Dock(TOP)
	dev:SetText("nZombies Unlimited Development")
	dev:SetFont("nzu_Font_Bloody_Medium")
	dev:SetContentAlignment(5)
	dev:SizeToContentsY()
	dev:SetTextColor(Color(255,50,50))
	local upcoming = bot:Add("DLabel")
	upcoming:SetText("Loading next project...")
	upcoming:Dock(TOP)
	upcoming:SetContentAlignment(5)
	upcoming:SetFont("Trebuchet24")
	upcoming:SizeToContentsY()

	local barholder = bot:Add("Panel")
	barholder:Dock(TOP)
	barholder:SetTall(70)

	local bar = barholder:Add("DPanel")
	bar:SetSize(400,15)
	bar.m_bDrawCorners = true
	
	local txt = barholder:Add("DLabel")
	txt:SetText("Fetching progress...")
	--txt:SetFont("Trebuchet18")
	txt:SetContentAlignment(5)
	txt:SetPos(0,15)

	local frac1 = 0
	local frac2 = 0
	http.Fetch(projectlink, function(body, size, headers, code)
		local _,_,str = string.find(body, "<title>(.+) · GitHub</title>")
		if str then upcoming:SetText(str) else upcoming:SetText("Couldn't load version name") end

		if not IsValid(txt) then return end

		local f1 = tonumber(string.match(body, '<span class="progress d%-inline%-block bg%-green" style="width: (%d*%.?%d+)%%">'))
		if f1 then frac1 = f1/100 end

		local f2 = tonumber(string.match(body, '<span class="progress d%-inline%-block bg%-purple" style="width: (%d*%.?%d+)%%">'))
		if f2 then frac2 = f2/100 end

		if f1 and f2 then
			txt:SetText("Done: "..math.Round(f1,1).."% || In Progress: "..math.Round(f2,1).."%")
		elseif f1 then
			txt:SetText("Done: "..math.Round(f1,1).."%")
		else
			txt:SetText("Couldn't retrieve progress.")
		end
	end)

	function bar:Paint(w,h)
		surface.SetDrawColor(0,0,0,150)
		surface.DrawRect(0,0,w,h)

		local w1 = (w-8)*frac1
		local w2 = (w-8)*frac2
		surface.SetDrawColor(0,255,0)
		surface.DrawRect(4,4,w1,h-8)

		surface.SetDrawColor(100,0,255)
		surface.DrawRect(4 + w1,4,w2,h-8)

		surface.SetDrawColor(150,150,150,200)
		surface.DrawRect(0,0,10,3)
		surface.DrawRect(0,3,3,2)
		surface.DrawRect(0,h-3,10,3)
		surface.DrawRect(0,h-5,3,2)
		surface.DrawRect(w-10,0,10,3)
		surface.DrawRect(w-3,3,3,2)
		surface.DrawRect(w-10,h-3,10,3)
		surface.DrawRect(w-3,h-5,3,2)
	end

	local visit = barholder:Add("DButton")
	visit:SetSize(200,25)
	visit:SetText("View project on Github")
	visit.DoClick = function()
		gui.OpenURL(projectlink)
	end

	function barholder:PerformLayout(w,h)
		bar:SetPos(w/2 - 200, 0)
		txt:SetWide(w)
		visit:SetPos(w/2 - 100, 45)
	end
	barholder:DockMargin(0,0,0,30)

	--[[-------------------------------------------------------------------------
	The content lists
	---------------------------------------------------------------------------]]
	local versions = bot:Add("DHorizontalScroller")
	versions:Dock(FILL)

	local current

	-- The base version
	local lastmade = vgui.Create("DPanel", versions)
	lastmade:SetWide(250 + 85*2)
	lastmade:SetPaintBackground(false)

	local box = vgui.Create("DPanel", lastmade)
	box:DockPadding(10,10,10,10)
	box:DockMargin(85,0,85,0)
	box.m_bDrawCorners = true

	local name = box:Add("DLabel")
	name:SetText(basevers)
	name:Dock(TOP)
	name:SetFont("HudHintTextLarge")
	name:SizeToContentsY()
	name:DockMargin(0,0,0,5)

	local scr = box:Add("DScrollPanel")
	scr:Dock(FILL)
	--scr:SetPaintBackground(true)

	box:Dock(LEFT)
	box:SetWide(250)
	versions:AddPanel(lastmade)

	for k,v in pairs(basevers2) do
		local chk = scr:Add("DCheckBoxLabel")
		chk:SetText(v)
		chk:SetChecked(true)
		chk:SetMouseInputEnabled(false)
		chk:SetKeyboardInputEnabled(false)
		chk:Dock(TOP)
		chk:DockMargin(0,0,0,2)
	end

	for k,v in pairs(projects) do
		local holder = vgui.Create("DPanel", versions)
		holder:SetWide(250 + 85*2)
		holder:SetPaintBackground(false)

		local box = vgui.Create("DPanel", holder)
		box:DockPadding(10,10,10,10)
		box:DockMargin(85,0,85,0)
		box.m_bDrawCorners = true

		local name = box:Add("DLabel")
		name:SetText("Loading version info ...")
		name:Dock(TOP)
		name:SetFont("HudHintTextLarge")
		name:SizeToContentsY()
		name:DockMargin(0,0,0,5)

		local scr = box:Add("DScrollPanel")
		scr:Dock(FILL)
		--scr:SetPaintBackground(true)

		box:Dock(LEFT)
		box:SetWide(250)
		versions:AddPanel(holder)

		http.Fetch(v, function(body)
			local _,_,str = string.find(body, "<title>(.+) · GitHub</title>")
			if str then name:SetText(str) else name:SetText("Couldn't load version name") end

			local _,_,numtodo = string.find(body, "To do</span>%s*<span class=\"Counter js%-column%-nav%-card%-count\" aria%-label=\"Contains (%d+) items\"")
			local _,_,numprogress = string.find(body, "In progress</span>%s*<span class=\"Counter js%-column%-nav%-card%-count\" aria%-label=\"Contains (%d+) items\"")
			local _,_,numdone = string.find(body, "Done</span>%s*<span class=\"Counter js%-column%-nav%-card%-count\" aria%-label=\"Contains (%d+) items\"")

			local completes = {}
			local incompletes = {}
			local progresses = {}

			local function applyinfo()
				for k,v in pairs(completes) do
					local chk = scr:Add("DCheckBoxLabel")
					chk:SetText(v)
					chk:SetChecked(true)
					chk:SetMouseInputEnabled(false)
					chk:SetKeyboardInputEnabled(false)
					chk:Dock(TOP)
					chk:DockMargin(0,0,0,2)
				end

				for k,v in pairs(progresses) do
					local chk = scr:Add("DCheckBoxLabel")
					chk:SetText(v)
					chk:SetMouseInputEnabled(false)
					chk:SetKeyboardInputEnabled(false)
					chk:Dock(TOP)
					chk:DockMargin(0,0,0,2)
					chk.Button.PaintOver = function(s,w,h)
						surface.SetDrawColor(255,255,255)
						local tall = h/5
						local widegap = w/5
						surface.DrawRect(widegap, h/2 - tall/2, w - widegap*2, tall)
					end
				end

				for k,v in pairs(incompletes) do
					local chk = scr:Add("DCheckBoxLabel")
					chk:SetText(v)
					chk:SetChecked(false)
					chk:SetMouseInputEnabled(false)
					chk:SetKeyboardInputEnabled(false)
					chk:Dock(TOP)
					chk:DockMargin(0,0,0,2)
				end

				local lbl = scr:Add("DLabel")
				local str = "To do: "..(numtodo or "??").." || In progress: "..(numprogress or "??").." || Done: "..(numdone or "??")
				lbl:SetText(str)
				lbl:Dock(TOP)
				lbl:DockMargin(0,5,0,0)
			end

			local done1,done2,done3
			local _,_,id = string.find(body, "<a data%-column%-id=\"(%d+)\" data%-column%-name=\"Done\"")
			if id then
				http.Fetch(v.."/columns/"..id.."/cards", function(body2)
					for s in string.gmatch(body2, "<div class=\"js%-comment%-body\">%s*<p>([%w%s]+)</p>") do
						table.insert(completes, s)
					end

					for s in string.gmatch(body2, "href=\"/Zet0rz/nZombies%-Unlimited/issues/%d+\">([%w%s]+)</a>") do
						table.insert(completes, s)
					end
					done1 = true
					if done2 and done3 then
						applyinfo()
					end
				end, function() done1 = true if done2 and done3 then applyinfo() end end)
			end

			local _,_,id = string.find(body, "<a data%-column%-id=\"(%d+)\" data%-column%-name=\"In progress\"")
			if id then
				http.Fetch(v.."/columns/"..id.."/cards", function(body2)
					for s in string.gmatch(body2, "<div class=\"js%-comment%-body\">%s*<p><em><strong>([%*%w%s]+)</strong></em></p>") do
						table.insert(progresses, s)
					end

					for s in string.gmatch(body2, "href=\"/Zet0rz/nZombies%-Unlimited/issues/%d+\">([%w%s]+)</a>") do
						table.insert(progresses, s)
					end
					done2 = true
					if done1 and done3 then
						applyinfo()
					end
				end, function() done2 = true if done1 and done3 then applyinfo() end end)
			end
			
			local _,_,id = string.find(body, "<a data%-column%-id=\"(%d+)\" data%-column%-name=\"To do\"")
			if id then
				http.Fetch(v.."/columns/"..id.."/cards", function(body2)
					for s in string.gmatch(body2, "<div class=\"js%-comment%-body\">%s*<p><em><strong>([%*%w%s]+)</strong></em></p>") do
						table.insert(incompletes, s)
					end

					for s in string.gmatch(body2, "href=\"/Zet0rz/nZombies%-Unlimited/issues/%d+\">([%w%s]+)</a>") do
						table.insert(incompletes, s)
					end
					done3 = true
					if done1 and done2 then
						applyinfo()
					end
				end, function() done3 = true if done1 and done2 then applyinfo() end end)
			end
		end, function() name:SetText("Couldn't load version") end)

		if v == projectlink then
			current = lastmade
			name:SetTextColor(Color(255,100,100))
		end
		lastmade = holder
	end

	if IsValid(current) then
		versions:ScrollToChild(current)
	end

	--[[-------------------------------------------------------------------------
	Legacy Config info
	---------------------------------------------------------------------------]]
	local top = vgui.Create("Panel", panel)
	top:Dock(TOP)
	top:SetTall(400)

	local head = top:Add("DLabel")
	head:SetText("Legacy Configs")
	head:SetFont("nzu_Font_Bloody_Medium")
	head:Dock(TOP)
	head:SizeToContentsY()
	head:SetContentAlignment(5)
	head:SetTextColor(Color(255,50,50))

	local desc = top:Add("DLabel")
	desc:SetText("You can use the list on the left to spawn entities from a legacy nZombies Config.")
	desc:Dock(TOP)
	desc:SizeToContentsY()
	desc:SetContentAlignment(5)
	local note2 = top:Add("DLabel")
	note2:SetText("You can then save a new Config in nZombies Unlimited format using these entities.")
	note2:SizeToContentsY()
	note2:Dock(TOP)
	note2:SetContentAlignment(5)

	local note3 = top:Add("DLabel")
	note3:SetText("Note that not all features are implemented in nZombies Unlimited yet, and these won't be spawned.")
	note3:SizeToContentsY()
	note3:Dock(TOP)
	note3:SetContentAlignment(5)
	note3:DockMargin(0,20,0,0)

	local scr3holder = top:Add("Panel")
	scr3holder:Dock(FILL)
	scr3holder:DockMargin(10,10,10,10)
	local scr3p = scr3holder:Add("DPanel")
	scr3p.m_bDrawCorners = true
	scr3p:SetWide(400)
	scr3p:DockPadding(5,5,5,5)
	local scr3 = scr3p:Add("DScrollPanel")
	scr3:Dock(FILL)

	function scr3holder:PerformLayout(w,h)
		scr3p:SetPos(w/2 - 200)
		scr3p:SetTall(h)
	end

	local zp = 1
	for k,v in SortedPairsByMemberValue(modules, "Label") do
		local chk = scr3:Add("DCheckBoxLabel")
		chk:SetText(v.Label)
		if v.Load then
			chk:SetChecked(true)
			chk:SetTextColor(Color(0,255,0))
		else
			chk:SetTextColor(Color(255,0,0))
		end
		chk:SetMouseInputEnabled(false)
		chk:SetKeyboardInputEnabled(false)
		chk:Dock(TOP)
		chk:DockMargin(0,0,0,2)
		--chk:SetZPos(zp)
		--zp = zp + 1
	end

	local separator = top:Add("DPanel")
	separator:Dock(BOTTOM)
	separator:SetTall(40)
	separator:DockMargin(0,20,0,20)
	--separator.Paint = function(s,w,h)
		--surface.SetDrawColor(0,0,0)
		--surface.DrawRect(0,0,w,h)
	--end
	separator.m_bDrawCorners = true

end, "icon16/bricks.png", "See the next update's contents, progress, and load Legacy Configs from original nZombies.")