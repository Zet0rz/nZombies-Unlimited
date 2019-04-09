local customtype = {
	NetSend = net.WriteString,
	NetRead = net.ReadString,
	Client = true, -- Always network these
}

if SERVER then
	nzu.AddCustomExtensionSettingType("HUDComponent", customtype)
	return
end

-- This file is now CLIENT only

--[[-------------------------------------------------------------------------
Structure of a HUD Component:

Component = {
	Create = function, on component activate
	Paint = function, every frame
	Draw = function, called manually from nzu.DrawHUDComponent
	Remove = function, remove/clean component
}
^ All fields are optional

Registration happens by pointing at an existing type, then giving the component a name and the component table
Types have to be registered or it will error (this is purely to cause errors if a category is mistyped)
---------------------------------------------------------------------------]]

local components = {}
function nzu.GetHUDComponentTypes()
	return table.GetKeys(components)
end

function nzu.RegisterHUDComponentType(type)
	components[type] = components[type] or {}
end

function nzu.GetHUDComponents(type)
	return table.GetKeys(components[type])
end

if NZU_SANDBOX then
	-- In Sandbox, we only need to register possible types and option names
	-- We can discard the actual component information

	local exts = {}
	function nzu.RegisterHUDComponent(type, name, component)
		assert(components[type], "Attempted to register HUD component to non-existing category '"..type.."'")

		components[type][name] = true

		-- Cause an update so panels will show this component under this type
		if CLIENT and exts[type] then
			exts[type]:RebuildPanels()
		end
	end

	customtype.Create = function(ext, setting)
		nzu.RegisterHUDComponentType(setting)
		exts[setting] = ext
	end
else
	local enabled = {}
	local paints = {}
	local function enable(type, name)
		local new = components[type][name]
		if new then
			local t2 = {ID = name}
			local value
			if new.Create then
				value = new.Create()
				t2.Value = value
			end

			t2.Draw = new.Draw -- Function-triggered (context) drawing
			t2.Remove = new.Remove
			if new.Paint then t2.PaintIndex = table.insert(paints, function() new.Paint(value) end) end -- Auto drawing (HUD)

			enabled[type] = t2
		end
	end

	local queue = {}
	function nzu.RegisterHUDComponent(type, name, component)
		assert(components[type], "Attempted to register HUD component to non-existing category '"..type.."'")

		components[type][name] = component

		if queue[type] == name or name == "Unlimited" then -- DEBUG
			enable(type, name)
			queue[type] = nil
		else
			-- Refresh
			local v = enabled[type]
			if v and v.ID == name then
				if v.Remove then v.Remove(v.Value) end
				enable(type, name)
			end
		end
	end

	local function doenable(k,v)
		if enabled[k] then
			local t = enabled[k]
			if t.ID == k then return end
			
			if t.Remove then t.Remove(t.Value) end
			if t.PaintIndex then table.remove(paints, t.PaintIndex) end
			enabled[k] = nil
		end
		enable(k,v)
	end

	local hookedsets = {}
	customtype.Create = function(ext, setting)
		nzu.RegisterHUDComponentType(setting)
		hookedsets[ext.ID] = true
	end

	hook.Add("nzu_ExtensionSettingChanged", "nzu_HUD_AutoSettingChangeSet", function(id, k, v)
		if hookedsets[id] and nzu.GetExtension(id).GetSettingsMeta()[k].Type == "HUDComponent" then
			doenable(k,v)
		end
	end)

	hook.Add("nzu_ExtensionLoaded", "nzu_HUD_AutoSettingLoad", function(name)
		if hookedsets[name] then
			local ext = nzu.GetExtension(name)
			for k,v in pairs(ext.GetSettingsMeta()) do
				if v.Type == "HUDComponent" then
					doenable(k,ext.Settings[k])
				end
			end
		end
	end)

	hook.Add("HUDPaint", "nzu_HUDComponentsPaint", function()
		for k,v in pairs(paints) do
			v()
		end
	end)

	-- Trigger drawing of context-based components
	function nzu.DrawHUDComponent(type, a,b,c) -- We can change this to support more arguments later if needed
		local comp = enabled[type]
		if comp and comp.Draw then comp.Draw(a,b,c) end
	end
end

customtype.CustomPanel = {
	Create = function(parent, ext, setting)
		local p = vgui.Create("DComboBox", parent)
		function p:OnSelect(index, value)
			self:Send()
		end

		p:AddChoice("None")
		if components[setting] then
			for k,v in pairs(nzu.GetHUDComponents(setting)) do
				print("Building", setting, v)
				p:AddChoice(v)
			end
		end

		return p
	end,
	Set = function(p,v)
		p:SetValue(v)
	end,
	Get = function(p)
		return p:GetSelected()
	end,
}
nzu.AddCustomExtensionSettingType("HUDComponent", customtype)

--[[-------------------------------------------------------------------------
Target ID Component
---------------------------------------------------------------------------]]
nzu.RegisterHUDComponentType("HUD_TargetID")

TARGETID_TYPE_GENERIC = 1
TARGETID_TYPE_USE = 2
TARGETID_TYPE_BUY = 3
TARGETID_TYPE_USECOST = 4
TARGETID_TYPE_PLAYER = 5
TARGETID_TYPE_ELECTRICITY = 6

if NZU_SANDBOX then
	surface.CreateFont("nzu_Font_TargetID", {
		font = "Trebuchet MS",
		size = 32,
		weight = 500,
		antialias = true,
		outline = true,
	})
end
local font = "nzu_Font_TargetID"

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

local function basiccomponent(typ, text, data, ent)
	local x,y = ScrW()/2, ScrH()/2 + 100
	local str = typeformats[typ] and typeformats[typ](text, data, ent) or text

	if str then
		draw.SimpleText(str, font, x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local dopaint
if NZU_NZOMBIES then
	dopaint = nzu.DrawHUDComponent
	nzu.RegisterHUDComponent("HUD_TargetID", "Unlimited", {
		Draw = basiccomponent,
	})
else
	dopaint = function(_, typ, text, data, ent)
		basiccomponent(typ, text, data, ent)
	end
	nzu.RegisterHUDComponent("HUD_TargetID", "Unlimited")
end

local targetidrange = 100
local function determinetargetstr()
	local ply = LocalPlayer()
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
		typ = TARGETID_TYPE_GENERIC
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
		if not typ then typ = TARGETID_TYPE_GENERIC end
		dopaint("HUD_TargetID", typ, text, data, ent)
		return true
	end
end

if NZU_SANDBOX then
	print("Added hook")
	hook.Add("HUDDrawTargetID", "nzu_TargetIDSimulate", determinetargetstr)
else
	GM.HUDDrawTargetID = determinetargetstr

	local PLAYER = FindMetaTable("Player")
	function PLAYER:GetTargetIDText()
		return nil, TARGETID_TYPE_PLAYER
	end
end