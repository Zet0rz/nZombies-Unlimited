--[[
English is the standard language that you should base your ID's off of.
If something isn't found in your language file then it will fall back to English.
Valid languages (from gmod's menu): bg cs da de el en en-PT es-ES et fi fr ga-IE he hr hu it ja ko lt nl no pl pt-BR pt-PT ru sk sv-SE th tr uk vi zh-CN zh-TW
You MUST use one of the above when using translate.AddLanguage
]]

--[[
RULES FOR TRANSLATORS!!
* Only translate formally. Do not translate with slang, improper grammar, spelling, etc.
* Comment out things that you have not yet translated in your language file.
  It will then fall back to this file instead of potentially using out of date wording in yours.
]]

translate.AddLanguage("en", "English")

-- Lobby stuff
LANGUAGE.character		= "Character"
LANGUAGE.load_config    = "Load Config"
LANGUAGE.name           = "Name" 
LANGUAGE.mute           = "Mute"
LANGUAGE.customize_player = "Customize Player"
LANGUAGE.player_models  = "Player Model"
LANGUAGE.bodygroups     = "Bodygroups"
LANGUAGE.skin           = "Skin"
LANGUAGE.no_bodygroups  = "There are no bodygroups for this model."
LANGUAGE.player_color   = "Player Color"
LANGUAGE.weapon_color   = "Weapon Color"
LANGUAGE.load_celected_config = "Load selected Config"
LANGUAGE.no_action      = "[No valid action]"
LANGUAGE.no_config_selected = "No Config selected"
LANGUAGE.use_config_load = "Use the Load Configs menu to select a Config to load."
LANGUAGE.ready           = "Ready"
LANGUAGE.unready         = "Unready"
LANGUAGE.spawn_in        = "Spawn in"
LANGUAGE.unspawn         = "Unspawn"
LANGUAGE.game_active     = "GAME ACTIVE"
LANGUAGE.game_starting   = "GAME STARTING - [Spawn in"
LANGUAGE.back            = "Back"
LANGUAGE.edit_selected_sandbox = "Edit selected in Sandbox"
LANGUAGE.are_you_sure    = "Are you sure you want to change to SANDBOX?"
LANGUAGE.mode_confirmation = "Mode change confirmation"
LANGUAGE.change_gamemode = "Change gamemode"
LANGUAGE.cancel          = "Cancel"
LANGUAGE.config_mismatch = "Config Mismatch!"
--[[LANGUAGE.discord_link = "Discord Link"
LANGUAGE.click_to_copy   = "Click to copy to clipboard"
LANGUAGE.copied          = "Copied!"
LANGUAGE.steam_overlay   = "Open in Steam Overlay"
LANGUAGE.music           = "Music"]]--
-- Round Stuff
LANGUAGE.round_survived_1  = "You survived 1 round."
LANGUAGE.you_survived    = "You survived"
LANGUAGE.game_over = "GAME OVER"
LANGUAGE.rounds          = "rounds."
LANGUAGE.round_starting  = "Round starting!"
LANGUAGE.round_now_is    = "Round is now"
LANGUAGE.you_survived_over = "GAME OVER! You survived"

-- Scoreboard
LANGUAGE.ping           = "Ping"
--[[LANGUAGE.revives        = "Revives" -- W.I.P.
LANGUAGE.headshots      = "Headshots"
LANGUAGE.downs          = "Downs"
LANGUAGE.kills          = "Kills"
LANGUAGE.score          = "Score"]]--
LANGUAGE.no_config      = "No Config Loaded"

