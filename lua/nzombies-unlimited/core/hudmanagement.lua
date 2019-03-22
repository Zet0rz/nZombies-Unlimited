-- This file is CLIENT only

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
local CORE = nzu.GetExtension("Core")

local components = {}
function nzu.GetHUDComponentTypes()
	return table.GetKeys(components)
end

function nzu.RegisterHUDComponentType(type)
	components[type] = components[type] or {}
	CORE:RebuildPanels() -- Cause a rebuild so that the panel will now display this new type
end

if NZU_SANDBOX then
	-- In Sandbox, we only need to register possible types and option names
	-- We can discard the actual component information

	function nzu.RegisterHUDComponent(type, name, component)
		assert(components[type], "Attempted to register HUD component to non-existing category '"..type.."'")

		table.insert(components[type], name)
		CORE:RebuildPanels() -- Cause an update so panels will show this component under this type
	end
	
	function nzu.GetHUDComponents(type)
		return components[type]
	end

	function CORE.OnHUDComponentsChanged(t) end -- Leave this empty just so it doesn't error but also does nothing
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
			if new.Paint then t2.PaintIndex = table.insert(paints, function() new.Paint(value) end) end -- Auto drawing (HUD)

			enabled[type] = t2
		end
	end

	local queue = {}
	function nzu.RegisterHUDComponent(type, name, component)
		assert(components[type], "Attempted to register HUD component to non-existing category '"..type.."'")

		components[type][name] = component
		CORE:RebuildPanels() -- Cause an update so panels will show this component under this type

		if queue[type] == name then
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

	function nzu.GetHUDComponents(type)
		return table.GetKeys(components[type])
	end

	function CORE.OnHUDComponentsChanged(t)
		print("It's changed!")
		PrintTable(t)
		for k,v in pairs(enabled) do
			-- If the already enabled component is not equal to the newly selected one
			if v.ID ~= t[k] then
				if v.Remove then v.Remove(v.Value) end
				if v.PaintIndex then table.remove(paints, v.PaintIndex) end

				-- Now add the new one
				enable(k, t[k])
			end
		end

		-- Enable all the ones that were previously not enabled
		for k,v in pairs(t) do
			if not enabled[k] then enable(k, t[k]) end
		end
	end

	-- DEBUG
	queue.Round = "Unlimited"
	queue.Points = "Unlimited"
	queue.ReviveProgress = "Unlimited"
	queue.DownedIndicator = "Unlimited"

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

-- Pre-register in Sandbox since the actual components are only registered in the gamemode
-- This enables them appearing in the dropdown menues in Sandbox under settings
if NZU_SANDBOX then
	nzu.RegisterHUDComponentType("Round")
	nzu.RegisterHUDComponent("Round", "Unlimited")

	nzu.RegisterHUDComponentType("Points")
	nzu.RegisterHUDComponent("Points", "Unlimited")

	nzu.RegisterHUDComponentType("Weapons")
	nzu.RegisterHUDComponent("Weapons", "Unlimited")
end


--[[-------------------------------------------------------------------------
Target ID Component
---------------------------------------------------------------------------]]
nzu.RegisterHUDComponentType("TargetID")

TARGETID_TYPE_GENERIC = 0
TARGETID_TYPE_USE = 1
TARGETID_TYPE_BUY = 2
TARGETID_TYPE_USECOST = 3
TARGETID_TYPE_PLAYER = 4

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
	[TARGETID_TYPE_USE] = function(a) return "Press E to "..a end,
	[TARGETID_TYPE_BUY] = function(a,b) return "Press E to buy "..a.." for "..b end,
	[TARGETID_TYPE_USECOST] = function(a,b) return "Press E to "..a.." for "..b end,
	[TARGETID_TYPE_PLAYER] = function(a) return a:Nick() end,
}
local color = color_white

local function basiccomponent(typ, text, data)
	local x,y = ScrW()/2, ScrH()/2 + 100
	local str = typeformats[typ] and typeformats[typ](text, data) or text

	if str then
		draw.SimpleText(str, font, x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local dopaint
if NZU_NZOMBIES then
	dopaint = nzu.DrawHUDComponent
	nzu.RegisterHUDComponent("TargetID", "Unlimited", {
		Draw = basiccomponent,
	})
else
	dopaint = function(_, typ, text, data)
		basiccomponent(typ, text, data)
	end
	nzu.RegisterHUDComponent("TargetID", "Unlimited")
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
		text, typ, data = hook.Run("nzu_GetTargetIDTextSpecial", ent) or (ent.GetTargetIDText and ent:GetTargetIDText()) or hook.Run("nzu_GetTargetIDText", ent)
		--print(text, typ, data)
	end

	if text then
		if not typ then typ = TARGETID_TYPE_GENERIC end
		dopaint("TargetID", typ, text, data)
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
		return self, TARGETID_TYPE_PLAYER
	end
end