
local tabname = "nZombies Unlimited"

local tabs = {}
tabs["Entities"] = {func = function(pnl)
	local ctrl = vgui.Create("SpawnmenuContentPanel", sh)
	ctrl:EnableSearch("nzu", "PopulateNZU")
	ctrl:CallPopulateHook("PopulateNZU")
	return ctrl
end, icon = "icon16/control_repeat_blue.png", tooltip = "nZombies Entities"}

function NZ:AddTab(name, panelfunc, icon, tooltip)
	tabs[name] = {func = panelfunc, icon = icon, tooltip = tooltip}
end

hook.Add("PopulateNZU", "AddNZUContent", function(pnlContent, tree, node)

	-- Get a list of available NPCs
	local NPCList = list.Get( "NPC" )

	-- Categorize them
	local Categories = {}
	for k, v in pairs( NPCList ) do

		local Category = v.Category or "Other"
		local Tab = Categories[ Category ] or {}

		Tab[ k ] = v

		Categories[ Category ] = Tab

	end

	-- Create an icon for each one and put them on the panel
	for CategoryName, v in SortedPairs( Categories ) do

		-- Add a node to the tree
		local node = tree:AddNode( CategoryName, "icon16/monkey.png" )

		-- When we click on the node - populate it using this function
		node.DoPopulate = function( self )

			-- If we've already populated it - forget it.
			if ( self.PropPanel ) then return end

			-- Create the container panel
			self.PropPanel = vgui.Create( "ContentContainer", pnlContent )
			self.PropPanel:SetVisible( false )
			self.PropPanel:SetTriggerSpawnlistChange( false )

			for name, ent in SortedPairsByMemberValue( v, "Name" ) do

				spawnmenu.CreateContentIcon( ent.ScriptedEntityType or "npc", self.PropPanel, {
					nicename	= ent.Name or name,
					spawnname	= name,
					material	= "entities/" .. name .. ".png",
					weapon		= ent.Weapons,
					admin		= ent.AdminOnly
				} )

			end

		end

		-- If we click on the node populate it and switch to it.
		node.DoClick = function( self )

			self:DoPopulate()
			pnlContent:SwitchPanel( self.PropPanel )

		end

	end

	-- Select the first node
	local FirstNode = tree:Root():GetChildNode(0)
	if (IsValid(FirstNode)) then
		FirstNode:InternalDoClick()
	end

end)

spawnmenu.AddCreationTab(tabname, function()
	local sh = vgui.Create("DPropertySheet")
	for k,v in pairs(tabs) do
		local pnl = v.func(sh)
		sh:AddSheet(k, pnl, v.icon, false, false, v.tooltip)
	end
	sh:SetSkin("nZombies Unlimited")
	
	return sh

end, "icon16/control_repeat_blue.png", 1000, "nZombies Unlimited: Entities, Logic, Controls")

