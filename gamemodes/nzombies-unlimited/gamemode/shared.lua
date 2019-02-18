GM.Name = "nZombies Unlimited"
GM.Author = "Zet0r"
GM.Email = "N/A"
GM.Website = "N/A"

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

-- Logic for loading modules from /lua/nzombies-unlimited
nzu = nzu or {}
function nzu.IsAdmin(ply) return ply:IsAdmin() end -- Replace this later

-- Globals to act like SERVER and CLIENT (reversed when modules are loaded in the sandbox)
NZU_SANDBOX = false
NZU_NZOMBIES = true

--[[-------------------------------------------------------------------------
Core Modules shared with Sandbox
---------------------------------------------------------------------------]]
loadfile_c("nzombies-unlimited/core/cl_nzombies_skin.lua")

loadfile("nzombies-unlimited/core/extensions/extension_manager.lua")
loadfile_c("nzombies-unlimited/core/extensions/extension_panels.lua")

loadfile("nzombies-unlimited/core/configs.lua")
loadfile_s("nzombies-unlimited/core/sv_saveload.lua")

--[[-------------------------------------------------------------------------
Gamemode-specific files
---------------------------------------------------------------------------]]
loadfile("menu/menu.lua")
loadfile_c("menu/menu_customizeplayer.lua")
