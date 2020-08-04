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
	}
}

local function deactivatehud()
	if hud then
		for k,v in pairs(hud) do
			if type(v) == "function" then
				local keyword,name = string.match(k, "([^_]+)_(.+)")
				if keyword and name and keywords[keyword] then
					keywords[keyword][2](hud, name)
				end
			end
		end
		hud.UNHOOK = true
	end

	paints = {}
end

local function setuphud(loaded)
	for k,v in pairs(loaded) do
		if type(v) == "function" then
			local keyword,name = string.match(k, "([^_]+)_(.+)")
			if keyword and name and keywords[keyword] then
				keywords[keyword][1](loaded, name, v)
			end
		end
	end
	nzu.HUD = loaded
	hud = loaded
	hud.UNHOOK = nil
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
	return loaded
end

--[[-------------------------------------------------------------------------
HUD Drawing
---------------------------------------------------------------------------]]
function GM:HUDPaint()
	for k,v in pairs(paints) do
		v(hud)
	end
end

-- Lua refresh: Reload the active HUD
if hud then
	deactivatehud()
	setuphud(hud)
end

--[[-------------------------------------------------------------------------
Observed player system
This system controls which player the HUD draws for. When spectating, this changes
to the spectated player. It is LocalPlayer() all other times.
---------------------------------------------------------------------------]]
local observedplayer
local function changeobservedplayer(new)
	observedplayer = new
	if hud then
		if hud.Panels then
			for k,v in pairs(hud.Panels) do
				if v.SetPlayer then v:SetPlayer(new) end
			end
		end
		
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
DEBUG CODE
---------------------------------------------------------------------------]]
if not hud then
	local loaded = loadhud("test")
	setuphud(loaded)
end

function nzu.HUDComponent() end
function nzu.DrawHUDComponent() end

function DebugHUDOn() setuphud(hud) end
function DebugHUDOff() deactivatehud() end