local hudpath = "nzombies-unlimited/huds/"

--[[-------------------------------------------------------------------------
Server adding all installed HUDs to clients
---------------------------------------------------------------------------]]
if SERVER then
	-- AddCSLuaFile all the HUDs, as well as network their names as options
	local files,_ = file.Find(hudpath.."*.lua", "LUA")
	for k,v in pairs(files) do
		AddCSLuaFile(hudpath..v)
	end
return end


--[[-------------------------------------------------------------------------
Activating HUDs from objects
---------------------------------------------------------------------------]]
local hud = nzu.HUD
local paints = {}
local defaultpaints = {}
local observedplayer = IsValid(LocalPlayer()) and IsValid(LocalPlayer():GetObserverTarget()) and LocalPlayer():GetObserverTarget() or LocalPlayer()

-- Use this to add a default paint function that will be run if the HUD does not implement "Paint_[name]".
-- Can be used for addon-based additions, allowing the HUD to implement a custom style, but not requiring "supporting" HUDs just to work
function nzu.AddDefaultHUDFunction(name, func) defaultpaints[name] = func end

-- A HUD Object may have functions that start with these keywords for this specific type of behavior
-- The first function is when the HUD is activated
-- The second function for when it is deactivated
local keywords = {
	Hook = {
		function(hud, name, func) hook.Add(name, hud, func) end,
		function(hud, name) hook.Remove(name, hud) end
	},
	Paint = {
		function(hud, name, func) paints[name] = func end,
		function(hud, name) paints[name] = nil end
	},
	Panel = {
		function(hud, name, func)
			if not hud.Panels then hud.Panels = {} end
			hud.Panels[name] = func(hud)
		end,
		function(hud, name)
			if hud.Panels and hud.Panels[name] then
				hud.Panels[name]:Remove()
				hud.Panels[name] = nil
			end
		end,
	},
	Initialize = {
		function(hud, name, func) func(hud) end,
	}
}

local function deactivatehud()
	if hud then
		for k,v in pairs(hud) do
			if type(v) == "function" then
				local keyword,name = string.match(k, "([^_]+)_(.+)")
				if keyword and name and keywords[keyword] and keywords[keyword][2] then
					keywords[keyword][2](hud, name)
				end
			end
		end
		hud.UNHOOK = true
	end

	paints = {}
end

local function setuphud(loaded)
	if IsValid(LocalPlayer()) then
		hud.Player = observedplayer
		
		local foundids = {}
		for k,v in pairs(loaded) do
			if type(v) == "function" then
				local keyword,name = string.match(k, "([^_]+)_(.+)")
				if keyword and name and keywords[keyword] then
					keywords[keyword][1](loaded, name, v)
					foundids[name] = true
				end
			end
		end

		-- Add all default paints that weren't added by the HUD
		for k,v in pairs(defaultpaints) do
			if not foundids[k] then paints[k] = v end
		end

		nzu.HUD = loaded
		hud = loaded
		hud.UNHOOK = nil
	else
		-- If the player isn't valid (yet), we initialize after the player has fully loaded in
		hook.Add("InitPostEntity", "nzu_InitializeHUD", function() setuphud(loaded) end)
	end
end

local function IsValidHUD(hud) return not hud.UNHOOK end
local function loadhud(class)
	local loaded = include(hudpath..class..".lua")

	-- Inheritance support? Uncomment this if so

	--[[if loaded.Base then
		local base = loadhud(loaded.Base)
		if base then
			for k,v in pairs(base) do
				if loaded[k] == nil then loaded[k] = v end
			end
			base.UNHOOK = true -- Make all hooks it added get removed immediately
		end
	end]]
	
	-- By adding this, the HUD is allowed to do hook.Add("SomeHook", self, function(self) end) which will automatically unhook when the HUD is disabled
	loaded.IsValid = IsValidHUD
	loaded.ClassName = class
	return loaded
end

--[[-------------------------------------------------------------------------
HUD Drawing
---------------------------------------------------------------------------]]
function GM:HUDPaint()
	for k,v in pairs(paints) do
		v(hud)
	end

	-- Base functionality
	hook.Run( "HUDDrawTargetID" )
	hook.Run( "HUDDrawPickupHistory" )
	hook.Run( "DrawDeathNotice", 0.85, 0.04 )
end

-- Lua refresh: Reload the active HUD
if hud then
	deactivatehud()
	hud = loadhud(hud.ClassName)
	setuphud(hud)
end

--[[-------------------------------------------------------------------------
Observed player system
This system controls which player the HUD draws for. When spectating, this changes
to the spectated player. It is LocalPlayer() all other times.
---------------------------------------------------------------------------]]
local function changeobservedplayer(new)
	observedplayer = new
	if hud then
		--[[if hud.Panels then
			for k,v in pairs(hud.Panels) do
				if v.SetPlayer then v:SetPlayer(new) end
			end
		end]]
		
		hud.Player = new
		if hud.OnPlayerChanged then hud:OnPlayerChanged(new) end
	end
end

hook.Add("Think", "nzu_HUD_ObservedTargetChange", function()
	local lp = LocalPlayer()
	local obs = lp:GetObserverTarget()
	local target = IsValid(obs) and obs or lp
	if observedplayer ~= target then
		changeobservedplayer(target)
	end
end)

function nzu.GetObservedPlayer() return observedplayer end


--[[-------------------------------------------------------------------------
Target ID System
---------------------------------------------------------------------------]]

local targetidrange = 100
function GM:HUDDrawTargetID()
	if hud and hud.DrawTargetID then
		local ply = observedplayer
		local dir = ply:GetAimVector()
		local start = EyePos()

		local tr = {
			start = start,
			endpos = start + dir*targetidrange,
			filter = ply
		}

		local res = util.TraceLine(tr)
		if not res.Hit then return end

		local ent = res.Entity
		if not IsValid(ent) then return end

		local str = ent:GetNW2String("nzu_TargetIDText") -- This takes priority over all others
		if str then
			if str ~= "" then
				hud:DrawTargetID(str, ent)
			end
		else
			local typ, str, val = hook.Run("nzu_GetTargetIDText", ent)
			local f = hud["DrawTargetID"..typ]
			if f then
				f(hud, str, ent, val)
			else
				-- The HUD can also implement this as a hook, but it's probably better to just implement all types you'd translate anyway
				local str2 = hook.Run("nzu_TranslateTargetID", ent, typ, str, val)
				if str2 then
					hud:DrawTargetID(str2, typ, str, ent, val)
				end
			end
		end
	end
end

-- Perform the code that will determine based on the entity given what type of Target ID we want to pass on to the HUD
-- In base, it is given by the function of the entity
function GM:nzu_GetTargetIDText(ent)
	return ent.GetTargetIDText and ent:GetTargetIDText()
end

local generictypes = {
	Use = "Press E to %s",
	UseCost = "Press E to %s for %c",
	Buy = "Press E to buy %s for %c",
	NoElectricity = "Requires Electricity",
	-- Player,
	PickUp = "Press E to pick up %s",
	Weapon = "Press E to pick up %s",
}

-- This hook translates a type, string, and value, into full text that will be put into the hook
-- This is the gamemode base translation in case the HUD doesn't implement the types, and no other hooks exist to translate
function GM:nzu_TranslateTargetID(ent, typ, str, val)
	local inp = generictypes[typ]
	if inp then
		return string.format(inp, str, val)
	end
	return str
end



--[[-------------------------------------------------------------------------
Setting-managed + Spawning/Unspawning activation
---------------------------------------------------------------------------]]
local SETTINGS = nzu.GetExtension("core")
function SETTINGS:OnHUDChanged(old, new)
	deactivatehud()

	if new ~= old then
		hud = loadhud(string.StripExtension(new))
		nzu.HUD = hud
	end

	if hud and not LocalPlayer():IsUnspawned() then
		setuphud(hud)
	end
end

hook.Add("nzu_PlayerInitialSpawned", "nzu_InitializeHUD", function(ply)
	timer.Simple(0, function()
		if ply == LocalPlayer() then
			if not hud then
				hud = loadhud(string.StripExtension(SETTINGS.HUD))
				nzu.HUD = hud
			end
			setuphud(hud)
		end
	end)
end)

hook.Add("nzu_PlayerUnspawned", "nzu_DeactivateHUD", function(ply)
	if ply == LocalPlayer() then
		deactivatehud()
	end
end)