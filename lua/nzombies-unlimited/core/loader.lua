-- Create a global module
nzu = nzu or {}

function nzu.IsAdmin(ply) return ply:IsAdmin() end -- TODO: Replace this later

-- Globals to act like SERVER and CLIENT (reversed when modules are loaded in the main mode)
NZU_SANDBOX = true
NZU_NZOMBIES = false

local function loadfile(f)
	if SERVER then AddCSLuaFile(f) end
	include(f)
end
local function loadfile_c(f)
	if SERVER then AddCSLuaFile(f) end
	if CLIENT then include(f) end
end
local function loadfile_s(f)
	if SERVER then include(f) end
end

--[[-------------------------------------------------------------------------
Spawnmenu & Panels Preparation
---------------------------------------------------------------------------]]
loadfile("utils.lua")
loadfile_c("cl_nzombies_skin.lua")
loadfile_c("cl_spawnmenu.lua")
loadfile("mismatch.lua")

--[[-------------------------------------------------------------------------
Configs & Saving
---------------------------------------------------------------------------]]
loadfile("configs.lua")
loadfile_c("config_panels.lua")
loadfile_s("sv_saveload.lua")
loadfile("extension_manager.lua")
loadfile_c("extension_panels.lua")

--[[-------------------------------------------------------------------------
Components & Modules
---------------------------------------------------------------------------]]
--loadfile("resources.lua")
--loadfile_c("hudmanagement.lua")
--loadfile("logic/logic_manager.lua")
loadfile("rooms.lua")

--[[-------------------------------------------------------------------------
Spawnmenu & Networking
---------------------------------------------------------------------------]]
--loadfile_s("logic/sv_logicmap.lua")
--loadfile_c("logic/cl_logicmap.lua")
loadfile_c("spawnmenu_saveload.lua")
--loadfile("spawnmenu_entities.lua")
loadfile_c("spawnmenu_extensions.lua")
loadfile("spawnmenu_tools.lua")
loadfile_c("spawnmenu_mismatch.lua")
loadfile("spawnmenu_legacyconfigs.lua")

--[[-------------------------------------------------------------------------
Core item population
---------------------------------------------------------------------------]]
loadfile("entities_tools/spawnpoints_sandbox.lua")
loadfile("entities_tools/doors_sandbox.lua")
loadfile("entities_tools/electricityswitch.lua")
loadfile("entities_tools/wallbuys.lua")
loadfile("entities_tools/navlocker_sandbox.lua")
loadfile("entities_tools/barricades.lua")
loadfile("entities_tools/invisiblewalls.lua")
loadfile("entities_tools/naveditor.lua")

--loadfile("entities_tools/thumbnail_camera.lua")
