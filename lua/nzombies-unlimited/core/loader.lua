-- Create a global module
nzu = nzu or {}

function nzu.IsAdmin(ply) return ply:IsAdmin() end -- Replace this later

-- Globals to act like SERVER and CLIENT (reversed when modules are loaded in the main mode)
NZU_SANDBOX = true
NZU_NZOMBIES = false

if SERVER then
	AddCSLuaFile("cl_nzombies_skin.lua")
	AddCSLuaFile("cl_spawnmenu.lua")
	AddCSLuaFile("entities.lua")
	AddCSLuaFile("logicmap.lua")
	AddCSLuaFile("configsettings.lua")
	AddCSLuaFile("spawnmenu_saveload.lua")
	AddCSLuaFile("configs.lua")
	AddCSLuaFile("cl_vgui_configtree.lua")
	AddCSLuaFile("logic/logic_manager.lua")
	AddCSLuaFile("logic/cl_logicmap.lua")
	AddCSLuaFile("spawnmenu_entities.lua")

	AddCSLuaFile("extensions/extension_manager.lua")
	AddCSLuaFile("extensions/extension_panels.lua")
	AddCSLuaFile("spawnmenu_extensions.lua")

	include("configs.lua")
	include("sv_saveload.lua")
	include("logic/sv_logicmap.lua")
	include("extensions/extension_manager.lua")
else
	include("cl_nzombies_skin.lua")
	include("cl_spawnmenu.lua")
	include("cl_vgui_configtree.lua")
	include("configs.lua")
	include("spawnmenu_saveload.lua")
	include("logic/cl_logicmap.lua")

	include("extensions/extension_panels.lua")
	include("extensions/extension_manager.lua")
	include("spawnmenu_extensions.lua")
end
include("entities.lua")
include("logicmap.lua")
include("configsettings.lua")
include("logic/logic_manager.lua")

include("spawnmenu_entities.lua")

-- Test unit
AddCSLuaFile("logic/nzu_logic_testunit.lua")
include("logic/nzu_logic_testunit.lua")

AddCSLuaFile("spawnmenu_entities_test.lua")
include("spawnmenu_entities_test.lua")