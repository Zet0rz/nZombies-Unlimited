-- Create a global module
nzu = nzu or {}

-- Globals to act like SERVER and CLIENT (reversed when modules are loaded in the main mode)
NZU_SANDBOX = true
NZU_NZOMBIES = false

if SERVER then
	AddCSLuaFile("cl_nzombies_skin.lua")
	AddCSLuaFile("cl_spawnmenu.lua")
	AddCSLuaFile("entities.lua")
	AddCSLuaFile("logicmap.lua")
	AddCSLuaFile("configsettings.lua")
	AddCSLuaFile("cl_saveload.lua")
	AddCSLuaFile("cl_vgui_configtree.lua")
	AddCSLuaFile("logic/logic_manager.lua")
	AddCSLuaFile("logic/cl_logicmap.lua")

	include("sv_saveload.lua")
	include("logic/sv_logicmap.lua")
else
	include("cl_nzombies_skin.lua")
	include("cl_spawnmenu.lua")
	include("cl_vgui_configtree.lua")
	include("cl_saveload.lua")
	include("logic/cl_logicmap.lua")
end
include("entities.lua")
include("logicmap.lua")
include("configsettings.lua")
include("logic/logic_manager.lua")

-- Test unit
AddCSLuaFile("logic/nzu_logic_testunit.lua")
include("logic/nzu_logic_testunit.lua")