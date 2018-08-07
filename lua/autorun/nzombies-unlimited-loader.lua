
-- Temporary to try another structure
if true then
	AddCSLuaFile("nzombies-unlimited/core/loader.lua")
	include("nzombies-unlimited/core/loader.lua")
return end

local mode = engine.ActiveGamemode()
print("Running NZ Lua: ", mode)
if mode ~= "sandbox" and mode ~= "base" then return end

-- Module logic
local modulepath = "nzombies-unlimited/modules/"
local searchpath = "GAME"
local prefix = "lua/"

local modules = {}
function GetNZUModule(key)
	return modules[key]
end

local loadluafiles -- Allow recursion
function loadluafiles(dir, filter)
	local f,d = file.Find(prefix..dir.."*", searchpath)
	for k,v in pairs(f) do
		local f2 = dir..v
		local sep = string.sub(v,1,3)
		if sep == "cl_" then
			if SERVER then AddCSLuaFile(f2) else include(f2) end
		elseif sep == "sv_" then
			if SERVER then include(f2) end
		else
			AddCSLuaFile(f2)
			include(f2)
		end
	end
	
	for k,v in pairs(d) do
		if (filter and not filter[v]) then loadluafiles(dir..v.."/") end
	end
end

local loadmodule
function loadmodule(dir, nofilter)
	-- Load all shared files and folders
	loadluafiles(dir, nofilter and {["entities"] = true} or {
		["sandbox"] = true,
		["nzombies-unlimited"] = true,
		["entities"] = true,
	})
	
	local entmeta = FindMetaTable("Entity")
	local oldent = ENT
	local f,d = file.Find(prefix..dir.."/entities/*.lua", searchpath)
	for k,v in pairs(f) do
		--[[ENT = {}
		--setmetatable(ENT, entmeta)
		if SERVER then AddCSLuaFile(dir.."/entities/"..v) end
		include(dir.."/entities/"..v)
		scripted_ents.Register(ENT, string.StripExtension(v))]]
	end
	ENT = oldent or nil
	
	--loadmodule(dir.."sandbox/*", true) -- Load sandbox files
end

local oldmod = NZ -- in case some addon needs it
local _,dirs = file.Find(prefix..modulepath.."*", searchpath)
for k,v in pairs(dirs) do
	NZ = {}
	loadmodule(modulepath..v.."/")
	loadmodule(modulepath..v.."/sandbox/")
	NZ.ModuleName = v
	modules[v] = NZ
end 

for k,v in pairs(modules) do
	if v.Initialize then v:Initialize() end
end

NZ = oldmod or nil -- Clean up