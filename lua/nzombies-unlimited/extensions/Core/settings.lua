local EXT = EXT or nzu.Extensions.core -- This protects against lua refresh where EXT is no longer valid
EXT.Settings = {

	-- Starting Items & Setup
	["StartWeapon"] = {
		Type = "Weapon",
		Default = "weapon_pistol",
		Label = "Starting Weapon",
		Order = 1,
	},
	["StartKnife"] = {
		Type = "Weapon",
		Default = "nzu_knife_crowbar",
		Label = "Default Knife",
		Order = 2,
	},
	["StartGrenade"] = {
		Type = "Weapon",
		Default = "nzu_grenade_mk3a2",
		Label = "Default Grenade",
		Order = 3,
	},
	["StartPoints"] = {
		Type = "Number",
		Default = 500,
		Integer = true,
		Label = "Starting Points",
		Order = 4,
	},

	-- HUD and Cosmetic settings
	["HUD"] = {
		Type = "FileDir", -- It is really just a string
		Path = "lua/nzombies-unlimited/huds/*.lua", -- Everything in this folder
		Files = true,
		Default = "unlimited.lua", -- The default HUD
		Client = true,
		Label = "HUD Style",
		Order = 6,
	},
	["RoundSounds"] = {
		Type = "FileDir",
		Path = "sound/nzu/round/*",
		Directories = true,
		Default = "classic",
		Label = "Round Sounds",
		Order = 7,
	},

	-- Announcer. The folder name for the folder to look for announcer sound files in
	["Announcer"] = {
		Type = "FileDir", -- It is really just a string
		Path = "sound/nzu/announcer/*", -- Everything in this folder
		Directories = true,
		Default = "samantha",
		Client = true,
		Label = "Announcer",
		Order = 8,
	},

	-- Mystery Box settings
	["MysteryBoxWeapons"] = {
		Type = "WeightedWeaponList",
		Notify = function(val, key, ext)
			--if NZU_NZOMBIES then timer.Simple(0.1, function() ext.ReloadModelsList() end) end
		end,
		Label = "Mystery Box Weapons",
		Order = 100,
	},

	-- Powerups Settings
	["EnablePowerups"] = {
		Type = "Boolean",
		Default = true,
		Label = "Enable Powerups",
		Order = 5,
	}
}