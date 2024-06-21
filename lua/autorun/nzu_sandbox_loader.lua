if not ConVarExists("nzu_sandbox_enable") then CreateConVar("nzu_sandbox_enable", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE}) end
if GetConVar("nzu_sandbox_enable"):GetBool() and engine.ActiveGamemode() == "sandbox" then
	NZU_SANDBOX = true -- Set the globals
	NZU_NZOMBIES = false

	print("NZOMBIES UNLIMITED: Loading Sandbox...")
		
	if SERVER then
		AddCSLuaFile("nzu/core/loader.lua")
		AddCSLuaFile("nzu/sandbox/sh_configs.lua")
		AddCSLuaFile("nzu/sandbox/tools.lua")
		
		include("nzu/core/loader.lua")
		include("nzu/sandbox/sh_configs.lua")
		include("nzu/sandbox/sv_configsave.lua")
		include("nzu/sandbox/tools.lua")
	else
		include("nzu/core/loader.lua")
		include("nzu/sandbox/sh_configs.lua")
		include("nzu/sandbox/tools.lua")
	end

	-- Load all modules last
	local _,modules = file.Find("nzu/core/modules/*", "LUA")
	for k,v in pairs(modules) do
		print("Module: ", v)
		for _,f in pairs(file.Find("nzu/core/modules/"..v.."/*.lua", "LUA")) do
			print(f)
			if SERVER and not string.StartsWith(f, "sv_") then AddCSLuaFile("nzu/core/modules/"..v.."/"..f) end
			if not string.StartsWith(f, CLIENT and "sv_" or "cl_") then include("nzu/core/modules/"..v.."/"..f) end
		end
	end
end