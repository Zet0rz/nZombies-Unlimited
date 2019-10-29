
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

settingtbl.Panel = function(parent, ext, setting)
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

	function p:SetValue(v)
		for k,data in pairs(self.Data) do
			if data == v then
				self:SetText(self:GetOptionText(k))
				self.selected = k
				return
			end
		end

		self.Choices[0] = v
		self.Data[0] = v
		self.selected = 0
		self:SetText(v)
	end

	function p:GetValue()
		local str,data = self:GetSelected()
		return data
	end
	return p
end

--[[-------------------------------------------------------------------------
Loading HUD Objects and activating them
---------------------------------------------------------------------------]]
if NZU_NZOMBIES then
	local argfuncs = {}
	local paints = {}
	local panels = {}
	local fallbacks = {}

	local activehud = nzu.ActiveHUD
	local deployed = false
	local function undeploy()
		for k,v in pairs(panels) do
			v:Remove()
		end
		paints = {}
		panels = {}

		if deployed and activehud and activehud.OnUndeployed then activehud:OnUndeployed() end
		deployed = false
	end

	--[[-------------------------------------------------------------------------
	Observed player system
	This system controls which player the HUD draws for. When spectating, this changes
	to the spectated player. It is LocalPlayer() all other times.
	---------------------------------------------------------------------------]]
	local observedplayer
	local function changeobservedplayer(new)
		observedplayer = new
		for k,v in pairs(panels) do
			if v.UpdateObservedTarget then
				local replacement = v:UpdateObservedTarget(new)
				if IsValid(replacement) then panels[k] = replacement end -- You can replace it by returning a new panel; though you SHOULD just update the panel
			end
		end

		if activehud then
			activehud.Player = new
			if activehud.OnPlayerChanged then activehud:OnPlayerChanged(new) end
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
	Deployment & Function handling
	---------------------------------------------------------------------------]]
	local function handlefunc(k,hud)
		local f = hud[k] -- Get the function from the HUD object
		if f == nil then f = fallbacks[k] end -- If it is NOT nil, then it is the fallback function (You can set HUD.Func = false to block components)
		if f then
			local args = argfuncs[k] -- If we have an argument function, use that
			if type(args) == "function" then
				local pnl = f(hud, observedplayer, args(observedplayer))
				if pnl then
					panels[k] = pnl -- The function returned something which means something was created, and this is not a paint
				else
					paints[k] = function() f(hud, observedplayer, args(observedplayer)) end -- Otherwise, wrap it using the HUD object itself (to allow 'self') and the arguments from argfunc
				end
			else
				local pnl = f(hud, observedplayer) -- Same, but without arguments
				if pnl then
					panels[k] = pnl
				else
					paints[k] = function() f(hud, observedplayer) end
				end
			end
		end
	end

	local function deploy(hud)
		for k,v in pairs(argfuncs) do
			handlefunc(k,hud)
		end
		for k,v in pairs(hud) do
			if string.sub(k, 1, 6) == "Paint_" then -- Paint_ functions are custom hooked by the HUD itself
				handlefunc(k,hud)
			end
		end

		hud.Player = observedplayer
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
			nzu.ActiveHUD = HUD
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
				nzu.ActiveHUD = HUD
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
			func(activehud, observedplayer, a,b,c,d,e)
		end
	end

	function nzu.GetActiveHUD() return activehud end

	--[[-------------------------------------------------------------------------
	Drawing Effects
	---------------------------------------------------------------------------]]
	function nzu.HUDEffect(id, a,b,c,d,e)
		local name = "Effect_"..id
		local func = activehud[name] or fallbacks[name]

		if func then
			hook.Add("HUDPaint", "nzu_HUD_Effect_"..id, function()
				if func(activehud, observedplayer, a,b,c,d,e) then
					hook.Remove("HUDPaint", "nzu_HUD_Effect_"..id)
				end
			end)
		end
	end

	--[[-------------------------------------------------------------------------
	Registering a HUD Component
	This will cause the associated key in the HUD object to be deployed. If 'argfunc' is passed
	this function will return the arguments that the HUD object will receive.
	If this is nil, no arguments. If this is false, it is equivalent of un-registering the Component again

	Supports adding a fallback function in case the HUD does not implement this Component.
	If a HUD wants to block it, it should implement it as a field with the value 'false'
	---------------------------------------------------------------------------]]
	function nzu.HUDComponent(key, argfunc, fallbackfunc)
		fallbacks[key] = fallbackfunc

		if string.sub(key, 1, 5) ~= "Draw_" and string.sub(key, 1, 7) ~= "Effect_" then -- Using Draw_'s and Effect_'s will just assign a fallback to these functions without hooking
			local enable = argfunc ~= false
			argfuncs[key] = enable and (argfunc or true) or nil

			if deployed then
				if enable then
					handlefunc(key, activehud)
				else
					paints[key] = nil
					if panels[key] then
						panels[key]:Remove()
					end
					panels[key] = nil
				end
			end
		end
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