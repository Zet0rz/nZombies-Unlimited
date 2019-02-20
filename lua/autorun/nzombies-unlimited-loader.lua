if not ConVarExists("nzu_sandbox_enable") then CreateConVar("nzu_sandbox_enable", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}) end
if GetConVar("nzu_sandbox_enable"):GetBool() then
	if engine.ActiveGamemode() == "sandbox" then
		print("NZOMBIES UNLIMITED: Loading Sandbox...")
		AddCSLuaFile("nzombies-unlimited/core/loader.lua")
		include("nzombies-unlimited/core/loader.lua")
	end
end