local EXTENSION = nzu.Extension()

AddCSLuaFile("hudmanagement.lua")
if CLIENT then include("hudmanagement.lua") end

AddCSLuaFile("points.lua")
include("points.lua")

AddCSLuaFile("round.lua")
include("round.lua")

