GM.Name = "nZombies Unlimited"
GM.Author = "Zet0r"
GM.Email = "N/A"
GM.Website = "N/A"

local function loadfile(f)
	if SERVER then AddCSLuaFile(f) end
	include(f)
end
-- Logic for loading modules from /lua/nzombies-unlimited
nzu = nzu or {}

-- Logic for loading gamemode-specific entries
loadfile("menu.lua")