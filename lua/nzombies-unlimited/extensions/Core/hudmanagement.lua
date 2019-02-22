-- This file is CLIENT only

local EXTENSION = nzu.Extension()
local HUD = EXTENSION.HUD or {}
EXTENSION.HUD = HUD

--[[-------------------------------------------------------------------------
Structure of a HUD Component:

Component = {
	Create = function, on component activate
	Paint = function, every frame
	Remove = function, remove/clean component
}
^ All fields are optional

Registration happens by pointing at an existing type, then giving the component a name and the component table
Types have to be registered or it will error (this is purely to cause errors if a category is mistyped)
---------------------------------------------------------------------------]]

local components = {}
function HUD.GetComponentTypes()
	return table.GetKeys(components)
end

function HUD.RegisterComponentType(type)
	components[type] = components[type] or {}
	EXTENSION:RebuildPanels() -- Cause a rebuild so that the panel will now display this new type
end

if NZU_SANDBOX then

	-- In Sandbox, we only need to register possible types and option names
	-- We can discard the actual component information

	function HUD.RegisterComponent(type, name, component)
		assert(components[type], "Attempted to register HUD component to non-existing category '"..type.."'")

		table.insert(components[type], name)
		EXTENSION:RebuildPanels() -- Cause an update so panels will show this component under this type
	end
	
	function HUD.GetComponents(type)
		return components[type]
	end

	function EXTENSION.OnHUDComponentsChanged(t) end -- Leave this empty just so it doesn't error but also does nothing
else
	local enabled = {}
	local draws = {}
	local function enable(type, new)
		if new then
			local t2 = {}
			local value
			if new.Create then
				value = new.Create()
				t2.Value = value
			end
			if new.Paint then t2.DrawIndex = table.insert(draws, function() new.Paint(value) end) end

			enabled[type] = t2
		end
	end

	local queue = {}
	function HUD.RegisterComponent(type, name, component)
		assert(components[type], "Attempted to register HUD component to non-existing category '"..type.."'")

		components[type][name] = component
		EXTENSION:RebuildPanels() -- Cause an update so panels will show this component under this type

		if queue[type] == name then enable(type, component) end
	end

	function HUD.GetComponents(type)
		return table.GetKeys(components[type])
	end

	function EXTENSION.OnHUDComponentsChanged(t)
		print("It's changed!")
		PrintTable(t)
		for k,v in pairs(enabled) do
			-- If the already enabled component is not equal to the newly selected one
			if v.ID ~= t[k] then
				if v.Remove then v.Remove(v.Value) end
				if v.DrawIndex then table.remove(draws, v.DrawIndex) end

				-- Now add the new one
				enable(k, components[k][t[k]])
			end
		end

		-- Enable all the ones that were previously not enabled
		for k,v in pairs(t) do
			if not enabled[k] then enable(k, components[k][t[k]]) end
		end
	end
	for k,v in pairs(EXTENSION.Settings.HUDComponents) do
		local c = components[k] and components[k][v]
		if c then
			enable(k, c)
		else
			queue[k] = v
		end
	end

	hook.Add("HUDPaint", "nzu_HUDComponents", function()
		for k,v in pairs(draws) do
			v()
		end
	end)
end

-- Pre-register in Sandbox since round.lua is only run in nZombies
if NZU_SANDBOX then
	EXTENSION.HUD.RegisterComponentType("Round")
	EXTENSION.HUD.RegisterComponent("Round", "Unlimited")
end