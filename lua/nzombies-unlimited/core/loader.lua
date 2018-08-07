-- Create a global module
nzu = nzu or {}

-- Globals to act like SERVER and CLIENT (reversed when modules are loaded in the main mode)
NZU_SANDBOX = true
NZU_NZOMBIES = false

if SERVER then
	AddCSLuaFile("cl_spawnmenu.lua")
	AddCSLuaFile("entities.lua")
	AddCSLuaFile("logicmap.lua")
	AddCSLuaFile("configsettings.lua")
	AddCSLuaFile("cl_saveload.lua")
	AddCSLuaFile("cl_vgui_configtree.lua")
	include("sv_saveload.lua")
else
	include("cl_spawnmenu.lua")
	include("cl_vgui_configtree.lua")
	include("cl_saveload.lua")
end
include("entities.lua")
include("logicmap.lua")
include("configsettings.lua")