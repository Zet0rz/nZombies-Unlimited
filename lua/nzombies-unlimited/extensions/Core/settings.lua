local EXTENSION = nzu.Extension()

local settings = {
	["StartWeapon"] = {
		Type = "Weapon",
		Default = "weapon_pistol",
	},

	["StartKnife"] = {
		Type = "Weapon",
		Default = "nzu_knife_crowbar",
	},

	["StartGrenade"] = {
		Type = "Weapon",
		Default = "nzu_grenade_mk3a2",
	},

	["StartPoints"] = {
		Type = "Number",
		Default = 500,
		Parse = function(n) return math.Round(n) end
	},

	["HUD"] = nzu.HUDSetting, -- This table is exposed in hudmanagement.lua
	
	["RoundSounds"] = {
		Type = "ResourceSet",
		Default = "classic", -- classic.lua, as found in lua/nzombies-unlimited/resourcesets/RoundSounds/classic.lua. It's a lua file extension, but not actual code (it's JSON). Lua is just necessary for Workshop
	},
}

if CLIENT then
	-- Pre-register these as their files are located in the gamemode, not appearing in sandbox

	local labelledsettings = {
		{"StartPoints", "Starting Points"},
		{"StartWeapon", "Starting Weapon"},
		{"StartKnife", "Starting Knife"},
		{"StartGrenade", "Starting Grenade"},
	}

	local panelfunc = function(p, SettingPanel)
		for k,v in pairs(labelledsettings) do
			local pnl = vgui.Create("Panel", p)
			pnl:SetTall(25)
			pnl:Dock(TOP)
			pnl:DockPadding(5,2,5,2)

			local lbl = pnl:Add("DLabel")
			lbl:SetText(v[2])
			lbl:Dock(LEFT)
			lbl:SetWide(125)
			lbl:DockMargin(0,0,10,0)

			local st = SettingPanel(v[1],pnl)
			st:Dock(FILL)
		end

		local lbl_hud = p:Add("DLabel")
		lbl_hud:Dock(TOP)
		lbl_hud:SetText("HUD Theme:")
		lbl_hud:DockMargin(5,2,5,10)
		lbl_hud:SetFont("Trebuchet18")

		local huds = SettingPanel("HUD", p)
		huds:SetTall(25)
		huds:Dock(TOP)

		local lbl_rsounds = p:Add("DLabel")
		lbl_rsounds:SetText("Round Sounds")
		lbl_rsounds:Dock(TOP)
		local roundsounds = SettingPanel("RoundSounds", p)
		roundsounds:SetTall(25)
		roundsounds:Dock(TOP)

		return p
	end
	return settings, panelfunc
end

return settings