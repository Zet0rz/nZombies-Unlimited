--[[
	Structure:
	category, id, data = {
		Class = string,
		PrintName = string,
		Material = png or model path,
		SpawnFunction = function(ent),
		Extension = string, <-- have this?
	}

	Category:
	name, icon
]]

local categories = {}
function nzu.AddSpawnmenuEntityCategory(name, icon)
	if CLIENT then
		if not categories[name] then categories[name] = {Entities = {}} end
		categories[name].Icon = icon
	end
end

function nzu.AddSpawnmenuEntity(category, id, data)
	if SERVER then
		data.Material = nil -- Not needed serverside
		categories[id] = data
	else
		if not categories[category] then categories[category] = {Entities = {}, Icon = "icon16/bricks.png"} end
		categories[category].Entities[id] = data
	end
end

cleanup.Register("nZombies Entities")

if CLIENT then
	local emptyfunc = function() end
	spawnmenu.AddContentType("nzu_Entity", function(p,d)
		if not d.Material then return end

		local icon = vgui.Create("ContentIcon", p)
		icon:SetContentType("nzu_Entity")
		icon:SetSpawnName(d.Class)
		icon:SetName(d.PrintName or d.Class or "[Unknown]")

		if string.GetExtensionFromFilename(d.Material) == "mdl" then
			icon.Image:Remove()

			icon.Image = vgui.Create("SpawnIcon", icon)
			icon.Image:SetPos(3, 3)
			icon.Image:SetSize(128 - 6, 128 - 6)
			icon.Image:SetMouseInputEnabled(true)
			icon.Image:SetZPos(-500)
			icon.Image:SetVisible(true)
			icon.Image.DoClick = function() icon:DoClick() end
			icon.Image.PaintAt = emptyfunc

			icon.Image:SetModel(d.Material)
			icon:Add(icon.Image)
		else
			icon:SetMaterial(d.Material)
		end
		icon:SetColor(Color(205, 92, 92, 255))
		--[[icon.OpenMenu = function( icon )

			local menu = DermaMenu()
				menu:AddOption( "Copy to Clipboard", function() SetClipboardText( obj.spawnname ) end )
				menu:AddOption( "Spawn Using Toolgun", function() RunConsoleCommand( "gmod_tool", "creator" ) RunConsoleCommand( "creator_type", "0" ) RunConsoleCommand( "creator_name", obj.spawnname ) end )
				menu:AddSpacer()
				menu:AddOption( "Delete", function() icon:Remove() hook.Run( "SpawnlistContentChanged", icon ) end )
			menu:Open()

		end]]

		if IsValid(p) then
			p:Add(icon)
		end

		return icon
	end)

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
					local icon = spawnmenu.CreateContentIcon("nzu_Entity", self.PropPanel, v2)
					icon.DoClick = function(icon)
						net.Start("nzu_spawnentity")
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

	nzu.AddSpawnmenuTab("Entities", "SpawnmenuContentPanel", function(panel)
		panel:EnableSearch("entities", "PopulatenZombiesEntities")
		panel:CallPopulateHook("PopulatenZombiesEntities")
	end, "icon16/bricks.png", "Spawn nZombies-related Entities")

else

	util.AddNetworkString("nzu_spawnentity")
	local function getentity(class, ply, tr)
		local sent = scripted_ents.GetStored(class)
		if sent then
			local sent = sent.t

			local SpawnFunction = scripted_ents.GetMember(class, "SpawnFunction")
			if SpawnFunction then
				return SpawnFunction(sent, ply, tr, class)
			end
		end

		local SpawnPos = tr.HitPos + tr.HitNormal * (tbl.NormalOffset or 16)
		local ent = ents.Create(class)
		ent:SetPos(SpawnPos)

		-- This flush calculation is copied from sandbox/gamemode/commands.lua in DoPlayerEntitySpawn
		local vFlushPoint = tr.HitPos - (tr.HitNormal * 512)
		vFlushPoint = ent:NearestPoint(vFlushPoint)
		vFlushPoint = ent:GetPos() - vFlushPoint
		vFlushPoint = tr.HitPos + vFlushPoint

		if class ~= "prop_ragdoll" then
			ent:SetPos(vFlushPoint)
		else
			-- With ragdolls we need to move each physobject
			local VecOffset = vFlushPoint - ent:GetPos()
			for i = 0, ent:GetPhysicsObjectCount() - 1 do
				local phys = ent:GetPhysicsObjectNum(i)
				phys:SetPos(phys:GetPos() + VecOffset)
			end
		end

		return entity
	end

	net.Receive("nzu_spawnentity", function(len, ply)
		local id = net.ReadString()

		if categories[id] then
			local class = categories[id].Class
			local func = categories[id].SpawnFunction
			local printname = categories[id].PrintName or class or "[Unknown]"

			local tr = ply:GetEyeTrace()
			local entity

			if class then
				entity = getentity(class, ply, tr)
			end
			if func then
				entity = func(entity, ply, tr) or entity
			end

			if type(entity) == "table" then
				undo.Create("nZombies Entities")
					undo.SetPlayer(ply)
					undo.SetCustomUndoText("Undone " .. printname)
					for k,v in pairs(entity) do
						undo.AddEntity(v)
						v:SetVar("Player", ply)
						v:SetCreator(ply)
						ply:AddCleanup("nZombies Entities", v)
					end
				undo.Finish("nZombies Entity: "..printname .. " (Multiple Entities)")
			elseif IsValid(entity) then
				entity:SetCreator(ply)
				class = entity:GetClass() or class

				undo.Create("nZombies Entities")
					undo.SetPlayer(ply)
					undo.AddEntity(entity)
					undo.SetCustomUndoText("Undone " .. printname)
				undo.Finish("nZombies Entity: "..printname .. " ("..(class or "Unknown Class")..")")

				ply:AddCleanup("nZombies Entities", entity)
				entity:SetVar("Player", ply)
			end
		end
	end)
end