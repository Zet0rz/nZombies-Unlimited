
local hudpath = "nzombies-unlimited/huds/"

local function loadhud(class, nobase)
	local old = HUD
	HUD = {}

	include(hudpath..class..".lua")
	HUD.ClassName = class

	if HUD.Base and not nobase then
		local base = loadhud(base)
		if base then
			table.Inherit(HUD, base)
		end
	end

	local ret = HUD
	HUD = old
	return ret
end

local settingtbl = {
	NetRead = net.ReadString,
	NetWrite = net.WriteString,
	Default = "unlimited",
	Client = true, -- Network to clients
}

if SERVER then

	-- AddCSLuaFile all the HUDs, as well as network their names as options
	local files,_ = file.Find(hudpath.."*.lua", "LUA")
	for k,v in pairs(files) do
		AddCSLuaFile(hudpath..v)
	end

	-- Network options for when clients would request them
	util.AddNetworkString("nzu_hud_options")
	local function networkoptions(ply)
		local files,_ = file.Find(hudpath.."*.lua", "LUA")
		local found = {}
		for k,v in pairs(files) do
			AddCSLuaFile(hudpath..v)

			local hud = loadhud(string.StripExtension(v), true)
			local name = hud.Name or hud.ClassName
			table.insert(found, {hud.ClassName, name})
		end

		local num = #found
		if num > 0 then
			net.Start("nzu_hud_options")
				net.WriteUInt(num, 8)
				for i = 1,num do
					local t = found[i]
					net.WriteString(t[1])
					net.WriteString(t[2])
				end
			net.Send(ply)
		end
	end

	if NZU_SANDBOX then
		hook.Add("PlayerInitialSpawn", "nzu_HUD_NetworkOptions", function(ply)
			networkoptions(ply)
		end)
	else
		net.Receive("nzu_hud_options", function(len, ply)
			if nzu.IsAdmin(ply) then networkoptions(ply) end
		end)
	end

	nzu.HUDSetting = settingtbl
return end

--[[-------------------------------------------------------------------------
The rest of this file is CLIENT only

- Application of networked setting
---------------------------------------------------------------------------]]
local sets
net.Receive("nzu_hud_options", function()
	local num = net.ReadUInt(8)
	local tbl = {}

	for i = 1,num do
		local class = net.ReadString()
		local name = net.ReadString()
		tbl[i] = {class, name}
	end

	if NZU_SANDBOX then sets = tbl end -- Only do this in Sandbox pretty much
	hook.Run("nzu_HUDListUpdated", tbl)
end)

settingtbl.Panel = {
	Create = function(parent, ext, setting)
		local p = vgui.Create("DComboBox", parent)

		function p:Populate(tbl)
			self:Clear()
			for k,v in pairs(tbl) do
				self:AddChoice(v[2], v[1])
			end
		end

		if NZU_SANDBOX then
			if sets then p:Populate(sets) end
		else
			-- Request options
			net.Start("nzu_hud_options")
			net.SendToServer()
		end
		hook.Add("nzu_HUDListUpdated", p, p.Populate)

		function p:OnSelect(index, value, data)
			self:Send()
		end
		return p
	end,
	Set = function(p,v)
		for k,data in pairs(p.Data) do
			if data == v then
				p:SetText(p:GetOptionText(k))
				p.selected = k
				return
			end
		end

		p.Choices[0] = v
		p.Data[0] = v
		p.selected = 0
		p:SetText(v)
	end,
	Get = function(p)
		local str,data = p:GetSelected()
		return data
	end,
}

--[[-------------------------------------------------------------------------
Loading HUD Objects and activating them
---------------------------------------------------------------------------]]
if NZU_NZOMBIES then
	local paints = {}
	local removals = {}
	local fallbacks = {}

	local activehud
	local deployed = false
	local function undeploy()
		for k,v in pairs(removals) do
			if type(v) == "function" then v() end
		end
		paints = {}
		removals = {}

		if deployed and activehud and activehud.OnUndeployed then activehud:OnUndeployed() end
		deployed = false
	end

	local function handlefunc(k,v,hud)
		if type(v) == "function" and string.sub(k, 1, 1) ~= "_" and string.sub(k, 1, 5) ~= "Draw_" then -- Draw_ functions are manually drawn through nzu library, _ functions are internals (ignored)
			local rem = v(hud)
			if rem then
				removals[k] = rem -- A function returned means something was created, and this it not a paint
			else
				paints[k] = function() v(hud) end -- Wrap it to emulate HUD: call (allowing subclasses to override HUD fields)
			end
		end
	end

	local function deploy(hud)
		for k,v in pairs(hud) do handlefunc(k,v,hud) end

		for k,v in pairs(fallbacks) do
			if not paints[k] and not removals[k] then
				handlefunc(k,v,hud) -- Deploy any fallbacks that aren't already made
			end
		end

		if hud.OnDeployed then hud:OnDeployed() end
		deployed = true
	end

	
	if IsValid(LocalPlayer()) then
		function nzu.SetHUD(class)
			undeploy()
			activehud = nil

			local HUD = loadhud(class)
			activehud = HUD
			if not LocalPlayer():IsUnspawned() then deploy(HUD) end
		end
		--nzu.SetHUD("Unlimited") -- DEBUG
	else
		function nzu.SetHUD(class)
			activehud = class
		end

		-- Delay deployment until InitPostEntity
		hook.Add("InitPostEntity", "nzu_HUD_Deploy", function()
			function nzu.SetHUD(class)
				undeploy()
				activehud = nil

				local HUD = loadhud(class)
				activehud = HUD
				if not LocalPlayer():IsUnspawned() then deploy(HUD) end
			end
			nzu.SetHUD(activehud)
		end)
	end
	

	hook.Add("nzu_PlayerUnspawned", "nzu_HUD_Disable", function(ply)
		if ply == LocalPlayer() then undeploy() end
	end)

	hook.Add("nzu_PlayerInitialSpawned", "nzu_HUD_Enable", function(ply)
		if ply == LocalPlayer() and activehud then deploy(activehud) end
	end)

	settingtbl.Notify = function(v)
		nzu.SetHUD(v)
	end

	hook.Add("HUDPaint", "nzu_HUD_Paint", function()
		for k,v in pairs(paints) do
			v()
		end
	end)

	--[[-------------------------------------------------------------------------
	Drawing Components
	---------------------------------------------------------------------------]]
	function nzu.DrawHUDComponent(id, a,b,c,d,e)
		local name = "Draw_"..id
		local func = activehud[name] or fallbacks[name]
		if func then
			func(activehud, a,b,c,d,e)
		end
	end

	function nzu.GetActiveHUD() return activehud end

	--[[-------------------------------------------------------------------------
	Individual Component fallback creation
	This can be used for "augmentations" - i.e. adding a HUD element to any HUD object
	so long as this object doesn't implement it itself

	If a HUD wants to block it, it should implement it as an empty function that returns true
	---------------------------------------------------------------------------]]
	function nzu.HUDComponent(key, func)
		fallbacks[key] = func
		if deployed and not paints[key] and not removals[key] then handlefunc(key, func, activehud) end -- Deploy it if there isn't another one in its slot
	end
end
nzu.HUDSetting = settingtbl

--[[-------------------------------------------------------------------------
Target ID System
---------------------------------------------------------------------------]]
TARGETID_TYPE_GENERIC = 1
TARGETID_TYPE_USE = 2
TARGETID_TYPE_BUY = 3
TARGETID_TYPE_USECOST = 4
TARGETID_TYPE_PLAYER = 5
TARGETID_TYPE_ELECTRICITY = 6

local typeformats = {
	[TARGETID_TYPE_USE] = function(text, data, ent) return "Press E to"..text end,
	[TARGETID_TYPE_BUY] = function(text, data, ent) return "Press E to buy"..text.."for "..data end,
	[TARGETID_TYPE_USECOST] = function(text, data, ent)
		return "Press E to"..text.."for "..data
	end,
	[TARGETID_TYPE_PLAYER] = function(text, data, ent) return ent:Nick() end,
	[TARGETID_TYPE_ELECTRICITY] = function(text) return text end,
}
local color = color_white

local targetidrange = 100
local function determinetargetstr()
	local ply = LocalPlayer() -- TODO: Change to spectator when implemented
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
	
	local text, typ, data
	local str = ent:GetNW2String("nzu_TargetIDText") -- This takes priority over all others
	if str and str ~= "" then
		text = str
	else
		-- The order goes: Special hook, ENT-defined, Normal hook
		text, typ, data = hook.Run("nzu_GetTargetIDTextSpecial", ent)
		if not text then
			if ent.GetTargetIDText then
				text, typ, data = ent:GetTargetIDText()
			end
		end
		if not text then
			text, typ, data = hook.Run("nzu_GetTargetIDText", ent)
		end
	end

	if text then
		return text, typ, data, ent
	end
end

if NZU_SANDBOX then
	surface.CreateFont("nzu_Font_TargetID", {
		font = "Trebuchet MS",
		size = 32,
		weight = 500,
		antialias = true,
		outline = true,
	})

	hook.Add("HUDDrawTargetID", "nzu_HUD_TargetIDSimulate", function()
		local text, typ, data, ent = determinetargetstr()
		if text then
			local x,y = ScrW()/2, ScrH()/2 + 100
			local str = typeformats[typ] and typeformats[typ](text, data, ent) or text

			if str then
				draw.SimpleText(str, "nzu_Font_TargetID", x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end)
end

if NZU_NZOMBIES then
	local drawcomponent = nzu.DrawHUDComponent

	function GM:HUDDrawTargetID()
		local text, typ, data, ent = determinetargetstr()
		if text then
			drawcomponent("TargetID", text, typ, data, ent)
		end
	end

	local PLAYER = FindMetaTable("Player")
	function PLAYER:GetTargetIDText()
		return nil, TARGETID_TYPE_PLAYER
	end
end