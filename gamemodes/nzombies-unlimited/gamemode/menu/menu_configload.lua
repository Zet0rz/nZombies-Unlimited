--[[-------------------------------------------------------------------------
Config Loading
---------------------------------------------------------------------------]]
if CLIENT then
	local configpaneltall = 60

	nzu.AddMenuHook("LoadConfig", function(menu)
		local function doconfigclick(cfg)
			if cfg then
				net.Start("nzu_menu_loadconfigs")
					net.WriteString(cfg.Codename)
					net.WriteString(cfg.Type)
				net.SendToServer()
			end
		end
		
		local l = vgui.Create("nzu_ConfigList")
		local sub = menu:AddPanel("Load Config ...", 3, l)
		l:Dock(FILL)
		l.OnConfigClicked = function(s,cfg,pnl)
			doconfigclick(cfg)
		end
		
		function sub:OnShown()
			l:LoadConfigs()
		end
		function sub:OnHid()
			l:Clear()
		end

		net.Receive("nzu_menu_loadconfigs", function()
			local c = {}
			c.Codename = net.ReadString()
			c.Type = net.ReadString()
			c.Name = net.ReadString()
			c.Map = net.ReadString()
			c.Authors = net.ReadString()

			menu:SetConfig(c)
		end)

	end)
end

if SERVER then
	util.AddNetworkString("nzu_menu_loadconfigs")

	local configtoload
	local function writeconfigtoload()
		net.WriteString(configtoload.Codename)
		net.WriteString(configtoload.Type)
		net.WriteString(configtoload.Name)
		net.WriteString(configtoload.Map)
		net.WriteString(configtoload.Authors)
	end

	net.Receive("nzu_menu_loadconfigs", function(len, ply)
		if not nzu.IsAdmin(ply) then return end

		local codename = net.ReadString()
		local ctype = net.ReadString()

		local config = nzu.GetConfig(codename, ctype)
		if config then
			configtoload = config
			net.Start("nzu_menu_loadconfigs")
				writeconfigtoload()
			net.Broadcast()
		end
	end)

	-- Players that join should see this on the menu
	hook.Add("PlayerInitialSpawn", "nzu_MenuLoadedConfig", function(ply)
		if configtoload then
			net.Start("nzu_menu_loadconfigs")
				writeconfigtoload()
			net.Send(ply)
		end
	end)
end