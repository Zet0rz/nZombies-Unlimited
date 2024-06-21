nzu = nzu or {}

-- Version properties
nzu.LatestConfigFormat = "nzu-v2"
nzu.Version = "v2.0"

if SERVER then
	AddCSLuaFile("nzu/core/permissions.lua")
	AddCSLuaFile("nzu/core/mismatch.lua")

	include("nzu/core/permissions.lua")
	include("nzu/core/sv_configs.lua")
	include("nzu/core/mismatch.lua")
else
	include("nzu/core/permissions.lua")
	include("nzu/core/mismatch.lua")
end