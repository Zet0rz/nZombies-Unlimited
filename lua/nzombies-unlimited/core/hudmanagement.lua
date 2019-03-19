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
	local draws = {}
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
			if new.Paint then t2.DrawIndex = table.insert(draws, function() new.Paint(value) end) end -- Auto drawing (HUD)

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
				if v.DrawIndex then table.remove(draws, v.DrawIndex) end

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
		for k,v in pairs(draws) do
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