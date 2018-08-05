GM.Name = "nZombies Unlimited"
GM.Author = "Alig96, Zet0r, Lolle"
GM.Email = "N/A"
GM.Website = "N/A"

-- Module logic
local gamemodepath = "nzombies-unlimited/gamemode/"
local modulepath = "nzombies-unlimited/modules/"

local modules = {}
function GetNZModule(key)
	return modules(key)
end

local loadluafiles -- Allow recursion
function loadluafiles(dir)
	local f,d = file.Find(dir)
	for k,v in pairs(f) do
		local sep = string.sub(v,1,3)
		if sep == "cl_" then
			if SERVER then AddCSLuaFile(v) else include(v) end
			return
		end
		if sep == "sv_" then
			if SERVER then include(v) end
			return
		end
		AddCSLuaFile(v)
		include(v)
	end
	
	for k,v in pairs(d) do
		loadluafiles(v)
	end
end

local oldmod = NZ -- in case some addon needs it

local _,dirs = file.Find(gamemodepath.."*", "DATA")
for k,v in pairs(dirs) do
	NZ = {}
	print(k,v)
	loadluafiles(v)
	NZ.ModuleName = v
	modules[v] = NZ
end

local _,dirs = file.Find(modulepath.."*", "DATA")
for k,v in pairs(dirs) do
	NZ = {}
	print(k,v)
	loadluafiles(v)
	NZ.ModuleName = v
	modules[v] = NZ
end

for k,v in pairs(modules) do
	if v.Initialize then v:Initialize() end
end

NZ = oldmod or nil -- Clean up