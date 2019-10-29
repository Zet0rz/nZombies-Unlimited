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
Hook prioritization! We overwrite hook functions to run our hooks first!
This will apply only to files loaded from here as it is reverted at the end of this file!
---------------------------------------------------------------------------]]

local oldadd = hook.Add
if hook.GetULibTable then -- ULib is installed which would break this hook system: We just gotta use their system with -1 as priority
	function hook.Add(ev,name,func)
		oldadd(ev,name,func,-1)
	end
else
	-- We do our own pre-hook implementation: All hooks added by the gamemode (non-dynamically) are added to 'prehooks' and all Calls run through that first
	local prehooks = nzu.GetPrioritizedHooks and nzu.GetPrioritizedHooks()
	local isstring = isstring
	local isfunction = isfunction

	if not prehooks then
		prehooks = {}
		local oldcall = hook.Call
		local IsValid = IsValid
		function hook.Call(name, gm, ...)
			local tbl = prehooks[name]
			if tbl ~= nil then
				local a,b,c,d,e,f
				for k,v in pairs(tbl) do
					if isstring(k) then
						a,b,c,d,e,f = v(...)
					else
						if IsValid(k) then
							a,b,c,d,e,f = v(k,...)
						else
							tbl[k] = nil
						end
					end

					if a ~= nil then
						return a,b,c,d,e,f
					end
				end
			end
			return oldcall(name, gm, ...) -- Call all other hooks and return their result
		end
	end

	-- Same as hook.Add, but for 'prehooks' instead
	function hook.Add(ev,name,func)
		if not isfunction(func) then return end
		if not isstring(ev) then return end

		if prehooks[ev] == nil then prehooks[ev] = {} end
		prehooks[ev][name] = func
	end

	function nzu.GetPrioritizedHooks() return prehooks end
end

--[[-------------------------------------------------------------------------
File loading
---------------------------------------------------------------------------]]


loadfile_c("fonts.lua")
loadfile("nzombies-unlimited/core/utils.lua")

--[[-------------------------------------------------------------------------
Extension Manager
---------------------------------------------------------------------------]]
loadfile("nzombies-unlimited/core/extension_manager.lua")
loadfile_c("nzombies-unlimited/core/extension_panels.lua")
--loadfile_c("nzombies-unlimited/core/hudmanagement.lua") -- Needed for the settings panel

--[[-------------------------------------------------------------------------
Core Modules shared with Sandbox
---------------------------------------------------------------------------]]
loadfile_c("nzombies-unlimited/core/cl_nzombies_skin.lua")

loadfile("nzombies-unlimited/core/configs.lua")
loadfile("nzombies-unlimited/core/mismatch.lua")
loadfile_c("nzombies-unlimited/core/config_panels.lua")
loadfile_s("nzombies-unlimited/core/sv_saveload.lua")
loadfile_s("nzombies-unlimited/core/rooms.lua") -- Only Server outside Sandbox

--[[-------------------------------------------------------------------------
Gamemode-specific files
---------------------------------------------------------------------------]]
loadfile("player.lua")
loadfile("playeruse.lua")

loadfile_c("menu/scoreboard.lua")

loadfile("electricity.lua")
loadfile("revive.lua")
loadfile("round.lua")
loadfile("points.lua")
loadfile_s("targeting.lua")
loadfile("weapons.lua")
--loadfile("viewmodeldisplay.lua")
loadfile_s("health.lua")
loadfile_s("spectating.lua")
loadfile("stamina.lua")

loadfile_c("ragdoll_cleanup.lua")

loadfile("menu/menu.lua")
loadfile("menu/menu_configload.lua")
loadfile_c("menu/menu_mismatch.lua")

loadfile("announcer.lua")

--[[-------------------------------------------------------------------------
Gamemode modules
---------------------------------------------------------------------------]]
loadfile_c("menu/menu_customizeplayer.lua")
loadfile_s("nzombies-unlimited/core/entities_tools/spawnpoints_nzu.lua")
loadfile("nzombies-unlimited/core/entities_tools/doors_nzu.lua")
loadfile("nzombies-unlimited/core/entities_tools/electricityswitch.lua")
loadfile_s("nzombies-unlimited/core/entities_tools/navlocker_nzu.lua")
loadfile("nzombies-unlimited/core/entities_tools/barricades.lua")
loadfile("nzombies-unlimited/core/entities_tools/wallbuys.lua")
loadfile("nzombies-unlimited/core/entities_tools/invisiblewalls.lua")
loadfile("nzombies-unlimited/core/entities_tools/naveditor.lua")

--[[-------------------------------------------------------------------------
Misc GM hooks
---------------------------------------------------------------------------]]
-- No noclipping!
function GM:PlayerNoClip(ply,on) return false end


--[[-------------------------------------------------------------------------
Sound play networking
---------------------------------------------------------------------------]]
if SERVER then
	util.AddNetworkString("nzu_sound") -- Server: Broadcast a sound filepath to play on clients

	function nzu.PlayClientSound(path, recipients)
		net.Start("nzu_sound")
			net.WriteString(path)
		if recipients then net.Send(recipients) else net.Broadcast() end
	end
else
	net.Receive("nzu_sound", function()
		surface.PlaySound(net.ReadString())
	end)
end

--[[-------------------------------------------------------------------------
Revert hook replacement
---------------------------------------------------------------------------]]

-- Restore the hook.Add function to whatever it was before
hook.Add = oldadd