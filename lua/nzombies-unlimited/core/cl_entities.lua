if CLIENT then
	local categories = {}
	hook.Add("PopulatenZombiesEntities", "AddnZombiesEntityContent", function(pnlContent, tree, node)
		for k,v in SortedPairs(categories) do
			local node = tree:AddNode(k, v.Icon or "icon16/bricks.png")

			node.DoPopulate = function(self)
				if self.PropPanel then return end
				self.PropPanel = vgui.Create("ContentContainer", pnlContent)
				self.PropPanel:SetVisible(false)
				self.PropPanel:SetTriggerSpawnlistChange(false)

				local entts = v.Entities
				for k2,v2 in SortedPairs(entts) do
					local icon = spawnmenu.CreateContentIcon("entity", self.PropPanel, v2)
					icon.DoClick = function(icon)
						net.Start("nzu_spawnentity")
							net.WriteString(k)
							net.WriteString(k2)
						net.SendToServer()
						surface.PlaySound("ui/buttonclickrelease.wav")
					end
				end
			end

			-- If we click on the node populate it and switch to it.
			node.DoClick = function(self)
				self:DoPopulate()
				pnlContent:SwitchPanel(self.PropPanel)
			end

		end

		-- Select the first node
		local FirstNode = tree:Root():GetChildNode(0)
		if IsValid(FirstNode) then
			FirstNode:InternalDoClick()
		end
	end)

	function nzu.AddEntityCategory(name, icon)
		if not categories[name] then categories[name] = {Entities = {}} end
		categories[name].Icon = icon
	end
	function nzu.AddEntity(category, class, printname, data, func)
		if not categories[category] then categories[category] = {Entities = {}} end
		categories[category].Entities[printname] = data
	end

	nzu.AddSpawnmenuTab("Entities", "SpawnmenuContentPanel", function(panel)
		panel:EnableSearch("entities", "PopulatenZombiesEntities")
		panel:CallPopulateHook("PopulatenZombiesEntities")
	end, "icon16/bricks.png", "Spawn nZombies-related Entities")
else
	local entities = {}
	function nzu.AddEntityCategory(name, icon)
		-- This is empty and only exists to allow shared definition without error
	end
	function nzu.AddEntity(category, class, printname, data, func, dist)
		if not entities[category] then entities[category] = {} end
		entities[category][printname] = {Class = class, SpawnFunction = func, NormalOffset = dist, Data = data}
	end

	util.AddNetworkString("nzu_spawnentity")
	local function getentity(class, ply, tbl, tr)
		local sent = scripted_ents.GetStored(class)
		if sent then
			local sent = sent.t

			local SpawnFunction = scripted_ents.GetMember(class, "SpawnFunction")
			if SpawnFunction then
				return SpawnFunction(sent, ply, tr, class)
			end
		end

		local SpawnPos = tr.HitPos + tr.HitNormal * (tbl.NormalOffset or 16)
		local entity = ents.Create(class)
		entity:SetPos(SpawnPos)
		return entity
	end
	net.Receive("nzu_spawnentity", function(len, ply)
		local cat = net.ReadString()
		local id = net.ReadString()

		if entities[cat] and entities[cat][id] then
			local class = entities[cat][id].Class
			local func = entities[cat][id].SpawnFunction

			local tr = ply:GetEyeTrace()
			local entity = getentity(class, ply, entities[cat][id], tr)
			if IsValid(entity) then
				if func then func(entity, ply, tr) end

				entity:SetCreator(ply)

				undo.Create("SENT")
					undo.SetPlayer(ply)
					undo.AddEntity(entity)
					undo.SetCustomUndoText("Undone " .. id)
				undo.Finish("Scripted Entity (" .. tostring(class) .. ")")

				ply:AddCleanup("sents", entity)
				entity:SetVar("Player", ply)
			end
		end
	end)
end