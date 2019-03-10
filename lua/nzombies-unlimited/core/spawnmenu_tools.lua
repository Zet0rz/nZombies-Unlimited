-- We're making a hacky way to add tools post-init
-- It works by queueing TOOL structures and immediately registrating them
-- once the ToolObj metatable becomes available (snatched from an actual tool)

local queue = {}
function nzu.RegisterTool(id, TOOL, nobuild)
	local stool = weapons.GetStored("gmod_tool")
	if stool then
		local _,any = next(stool.Tool)
		if any then
			local ToolObj = getmetatable(any)
			if ToolObj then
				local o = ToolObj:Create()
				table.Merge(o, TOOL)

				o.Tab = "nzu"
				local mode = "nzu_tool_"..id
				o.Mode = mode
				o:CreateConVars()
				stool.Tool[mode] = o

				if CLIENT then
					spawnmenu.AddToolMenuOption(
						"nzu",
						o.Category or "Uncategorized",
						mode,
						o.Name or "#"..mode,
						o.Command or "gmod_tool "..mode,
						o.ConfigName or mode,
						o.BuildCPanel
					)

					if not nobuild and IsValid(g_SpawnMenu) and IsValid(g_SpawnMenu.ToolMenu) then
						for k,v in pairs(g_SpawnMenu.ToolMenu:GetItems()) do
							if v.Name == "nZombies Unlimited" then
								--g_SpawnMenu.ToolMenu:CloseTab(v.Tab, true)
								for k2,v2 in pairs(spawnmenu.GetTools()) do
									if v2.Name == "nzu" then
										v.Panel.List:Clear()
										v.Panel:LoadToolsFromTable(v2.Items)
										break
									end
								end
							end
						end
						--g_SpawnMenu.ToolMenu:Clear()
						--g_SpawnMenu.ToolMenu.ToolPanels = {}
						--g_SpawnMenu.ToolMenu:LoadTools() -- Rebuild
					end
				end
			end
			return
		end
	end

	-- If it couldn't perform the extraction, queue it
	queue[id] = TOOL
end

hook.Add("InitPostEntity", "nzu_BuildQueuedTools", function()
	for k,v in pairs(queue) do
		nzu.RegisterTool(k,v, true)
	end
	if CLIENT and IsValid(g_SpawnMenu) and IsValid(g_SpawnMenu.ToolMenu) then
		for k,v in pairs(g_SpawnMenu.ToolMenu:GetItems()) do
			if v.Name == "nZombies Unlimited" then
				--g_SpawnMenu.ToolMenu:CloseTab(v.Tab, true)
				for k2,v2 in pairs(spawnmenu.GetTools()) do
					if v2.Name == "nzu" then
						v.Panel.List:Clear()
						v.Panel:LoadToolsFromTable(v2.Items)
						break
					end
				end
			end
		end
	end
	queue = nil
end)

if CLIENT then
	hook.Add("AddToolMenuTabs", "nzu_ToolMenuTab", function()
		spawnmenu.AddToolTab("nzu", "nZombies Unlimited", "icon16/briefcase.png")
	end)
end