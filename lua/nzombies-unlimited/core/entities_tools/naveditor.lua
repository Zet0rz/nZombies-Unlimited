if SERVER then
	local function loadnavmeshtable(tbl)
		navmesh.Reset()
		local areas = {}
		for k,v in pairs(tbl) do
			local area = navmesh.CreateNavArea(Vector(), Vector())
			for i = 0, 3 do
				area:SetCorner(i, v.Corners[i])
			end
			area:SetAttributes(v.Attributes)
			areas[k] = area
		end
		
		-- Create connections
		for k,v in pairs(tbl) do
			local area = areas[k]
			if v.Connections then
				for k2,v2 in pairs(v.Connections) do
					if areas[v2] then
						
						-- Ensure the target area is in a straight line somewhere from the first by ensuring their corners are within ranges!
						local from1 = area:GetCorner(0) -- NORTH_WEST
						local from2 = area:GetCorner(2) -- SOUTH_EAST
						local to1 = areas[v2]:GetCorner(0) -- NORTH_WEST
						local to2 = areas[v2]:GetCorner(2) -- SOUTH_EAST

						if (from1.x < to2.x and from2.x > to1.x) or (from1.y < to2.y and from2.y > to1.y) then
							area:ConnectTo(areas[v2])
						else
							print("nzu_navmesh: Navmesh file attempts to connect area ["..k.."] to ["..v2.."] without a window between them.")
						end
					else
						print("nzu_navmesh: Navmesh file attempts to connect area ["..k.."] with non-existent area ["..v2.."]!")
					end
				end
			end
			--[[if v.Parent then
				if areas[v.Parent] then
					area:SetParent(areas[v.Parent])
				else
					print("nzu_navmesh: Navmesh file attempts to parent area ["..k.."] to non-existent area ["..v2.."]!")
				end
			end]]
		end
	end

	-- We overwrite navmesh.Load - That way, any code attempting to load the navmesh will load the Config's, if it exists
	local oldload = navmesh.Load
	function navmesh.Load()
		local str = nzu.ReadConfigFile("navmesh")
		if str then
			loadnavmeshtable(util.JSONToTable(str))
		else
			oldload()
		end
	end

	local function savenavmeshtable()
		local tbl = {}
		for k,v in ipairs(navmesh.GetAllNavAreas()) do
			local t = {}
			t.Attributes = v:GetAttributes()
			
			t.Corners = {}
			for i = 0, 3 do
				t.Corners[i] = v:GetCorner(i)
			end
			
			local connections = v:GetAdjacentAreas()
			if connections and table.Count(connections) > 0 then
				t.Connections = {}
				for k2,v2 in pairs(connections) do
					table.insert(t.Connections, v2:GetID())
				end
			end
			if v:GetParent() then t.Parent = v:GetParent():GetID() end
			
			tbl[v:GetID()] = t
		end
		return tbl
	end
	
	-- Save/Load requestsing
	if NZU_SANDBOX then
		util.AddNetworkString("nzu_customnavmesh")
		net.Receive("nzu_customnavmesh", function(len, ply)
			if nzu.IsAdmin(ply) then
				if net.ReadBool() then
					if not nzu.WriteConfigFile("navmesh", util.TableToJSON(savenavmeshtable())) then
						ply:ChatPrint("Cannot write Config Navmesh file when no Config is being edited.")
					end
				else
					local str = nzu.ReadConfigFile("navmesh")
					if str then
						loadnavmeshtable(util.JSONToTable(str))
					else
						navmesh.Reset() -- We still reset on no file. It's to indicate it is cleared (players can then just reload global)
					end
				end
			else
				ply:ChatPrint("Only Admins may save or load the Navmesh files.")
			end
		end)
	end
end

if not NZU_SANDBOX then return end

-- Client request
if CLIENT then
	function nzu.RequestNavmeshSave()
		net.Start("nzu_customnavmesh")
			net.WriteBool(true)
		net.SendToServer()
	end
	
	function nzu.RequestNavmeshLoad()
		net.Start("nzu_customnavmesh")
			net.WriteBool(false)
		net.SendToServer()
	end
end

local TOOL = {}
TOOL.Category = "Navigation"
TOOL.Name = "#tool.nzu_tool_naveditor.name"
TOOL.nzu_NavEdit = true

TOOL.ClientConVar = {
	["left"] = "",
	["right"] = "",
}

-- Enable nav_edit on deploy, only if admin or it's not already enabled
function TOOL:Deploy()
	if SERVER then
		if not GetConVar("nav_edit"):GetBool() then
			if nzu.IsAdmin(self:GetOwner()) then
				RunConsoleCommand("nav_edit", "1")
			else
				self:GetOwner():ChatPrint("You can only use this tool while nav_edit is set to 1. Admins may do this in the server console, or by deploying this tool.")
			end
		end
	end
end

-- Disable nav_edit on holster, only if it is already enabled and no other players hold an editing tool
function TOOL:Holster()
	if SERVER then
		if GetConVar("nav_edit"):GetBool() then
			for k,v in pairs(player.GetAll()) do
				if v ~= self:GetOwner() and v:Alive() and nzu.IsAdmin(v) then
					local tool = v:GetTool()
					if tool and tool.nzu_NavEdit then return true end
				end
			end
			RunConsoleCommand("nav_edit", "0")
		end
	end
	return true
end

local commands = {
	["create"] = {
		Label = "Create area",
		Stages = {
			[0] = {
				Information = "Begin area",
				Command = "nav_begin_area",
			},
			[1] = {
				Information = "End area",
				Command = "nav_end_area",
				Cancel = "nav_begin_area",
			}
		}
	},
	["delete"] = {
		Label = "Delete area",
		Information = "Delete targeted area",
		Command = "nav_delete"
	},
	["connect"] = {
		Label = "Connect areas",
		Information = "Connect marked area to targeted area",
		Command = "nav_connect",
		Mark = true,
	},
	["disconnect"] = {
		Label = "Disconnect areas",
		Information = "Disconnected marked and targeted areas",
		Command = "nav_disconnect",
		Mark = true,
	},
	["merge"] = {
		Label = "Merge areas",
		Information = "Merge marked and targeted areas",
		Command = "nav_merge",
		Mark = true,
	},
	["split"] = {
		Label = "Split area",
		Information = "Split area at white line",
		Command = "nav_split",
	},
	["splice"] = {
		Label = "Splice areas",
		Information = "Create area between marked and targeted areas",
		Command = "nav_splice",
		Mark = true,
	},
	["subdivide"] = {
		Label = "Subdivide Area",
		Information = "Subdivide targeted area into 4 smaller areas",
		Command = "nav_subdivide"
	}
}

local function performcommand(self, mode)
	if mode and commands[mode] then
		local t = commands[mode]
		if self:GetStage() > 0 or t.Stages then
			if t.Stages and t.Stages[self:GetStage()] then
				if SERVER then
					RunConsoleCommand(t.Stages[self:GetStage()].Command)
					local tstage = self:GetStage() + 1
					self:SetStage(t.Stages[tstage] and tstage or 0)
				end
				return true
			end
		else
			if SERVER then
				if not t.Mark or IsValid(navmesh.GetMarkedArea()) then
					RunConsoleCommand(t.Command)
				else
					RunConsoleCommand("nav_mark")
				end
			end
			return true
		end
	end
end

function TOOL:LeftClick(trace)
	if not self.ActiveSide or self.ActiveSide == "left" then
		local result = performcommand(self, self:GetClientInfo("left"))
		if SERVER then
			if self:GetStage() > 0 then
				self.ActiveSide = "left"
				self.LastActiveCommand = self:GetClientInfo("left")
			else
				self.ActiveSide = nil
				self.LastActiveCommand = nil
			end
		end
		return result
	end
end

function TOOL:RightClick(trace)
	if not self.ActiveSide or self.ActiveSide == "right" then
		local result = performcommand(self, self:GetClientInfo("right"))
		if SERVER then
			if self:GetStage() > 0 then
				self.ActiveSide = "right"
				self.LastActiveCommand = self:GetClientInfo("right")
			else
				self.ActiveSide = nil
				self.LastActiveCommand = nil
			end
		else
			self.LastSide = "right"
		end
		return result
	end
end

local function docancel(self, mode)
	if mode and commands[mode] and commands[mode].Stages and commands[mode].Stages[self:GetStage()] and commands[mode].Stages[self:GetStage()].Cancel then
		RunConsoleCommand(commands[mode].Stages[self:GetStage()].Cancel)
	end
end
function TOOL:Reload(trace)
	if SERVER then
		if self:GetStage() > 0 then
			docancel(self, self:GetClientInfo("left"))
			docancel(self, self:GetClientInfo("right"))
			self:SetStage(0)
		end
		if IsValid(navmesh.GetMarkedArea()) then
			RunConsoleCommand("nav_unmark")
		end
		self.LastActiveCommand = nil
	end
	self.ActiveSide = nil
	return true
end

if SERVER then
	function TOOL:Think()
		if self.ActiveSide and self:GetClientInfo(self.ActiveSide) ~= self.LastActiveCommand then
			docancel(self, self.LastActiveCommand) -- Reset if we switch tools when we have an active side that isn't equal
			self:SetStage(0)
		end
	
		local b = IsValid(navmesh.GetMarkedArea())
		if b ~= self:GetWeapon():GetNWBool("is_area_marked") then
			self:GetWeapon():SetNWBool("is_area_marked", b)
		end
	end
end

if CLIENT then
	local cancel = {name = "reload"}
	local left = {name = "unknown", icon = "gui/lmb.png"}
	local right = {name = "unknown", icon = "gui/rmb.png"}
	
	TOOL.Information = {left, right}
	
	local function refreshinfo(self, side)
		local index = side == "left" and 1 or 2
		if self.ActiveSide and self.ActiveSide ~= side then
			self.Information[index] = nil
			return
		elseif not self.Information[index] then
			self.Information[index] = side == "left" and left or right
		end
	
		local t = self.Information[index]
		local mode = self:GetClientInfo(side)
		if mode and commands[mode] then
			local cmd = commands[mode]
			if cmd.Stages then
				t.name = mode..self:GetStage()
			elseif cmd.Mark and not self:GetWeapon():GetNWBool("is_area_marked", false) then
				t.name = "mark"
			else
				t.name = mode
			end
			return
		end
		t.name = "unknown"
	end
	
	function TOOL:Think()
		local ismarked = self:GetWeapon():GetNWBool("is_area_marked")
		if self:GetStage() ~= self.LastStage or ismarked ~= self.LastMarked then
			self.LastLeft = nil
			self.LastRight = nil
			
			self.LastStage = self:GetStage()
			self.LastMarked = ismarked
			self.ActiveSide = self:GetStage() > 0 and self.LastSide or nil
		end
		
		local lmode = self:GetClientInfo("left")
		if lmode ~= self.LastLeft then
			refreshinfo(self, "left")
			self.LastLeft = lmode
		end
		
		local rmode = self:GetClientInfo("right")
		if rmode ~= self.LastRight then
			refreshinfo(self, "right")
			self.LastRight = rmode
		end
		
		local tocancel = self:GetStage() > 0 or ismarked
		if tocancel ~= self.LastCancel then
			self.Information[3] = tocancel and cancel or nil
			self.LastCancel = tocancel
		end
	end
	
	-- Language add for all commands
	language.Add("tool.nzu_tool_naveditor.name", "Nav Editor")
	language.Add("tool.nzu_tool_naveditor.desc", "A tool for editing the Navigation Mesh, including saving the modified mesh as nZombies-only.")
	
	language.Add("tool.nzu_tool_naveditor.unknown", "No Command")
	language.Add("tool.nzu_tool_naveditor.reload", "Cancel/Unmark")
	language.Add("tool.nzu_tool_naveditor.mark", "Mark area")
	for k,v in pairs(commands) do
		if v.Information then language.Add("tool.nzu_tool_naveditor."..k, v.Information) end
		if v.Stages then
			for k2,v2 in pairs(v.Stages) do
				language.Add("tool.nzu_tool_naveditor."..k..k2, v2.Information)
			end
		end
	end
	
	function TOOL.BuildCPanel(panel)
		panel:Help("This tool lets you bind various Nav Editing commands to Left and Right click.")
		panel:Help("Left or Right-click a row in the box below to bind that command to that mouse button.")
	
		local listbox = vgui.Create("DListView", panel)
		listbox:SetTall(17 + 17*table.Count(commands))
		listbox:AddColumn("Commands")
		listbox:AddColumn("Left"):SetMaxWidth(35)
		listbox:AddColumn("Right"):SetMaxWidth(35)
		listbox.Lines = {}
		
		local cvl = GetConVar("nzu_tool_naveditor_left")
		local cvr = GetConVar("nzu_tool_naveditor_right")
		for k,v in pairs(commands) do			
			local line = listbox:AddLine(v.Label, "", "")
			line.Columns[2]:SetContentAlignment(5)
			line.Columns[3]:SetContentAlignment(5)
			
			function line:OnMousePressed(code)
				local cv = code == MOUSE_LEFT and cvl or code == MOUSE_RIGHT and cvr
				if cv then
					cv:SetString(k)
				end
			end
			
			listbox.Lines[k] = line
		end
		
		function listbox:Think()
			if self.SelectedLeft ~= cvl:GetString() then
				local oldline = self.SelectedLeft and self.Lines[self.SelectedLeft]
				if IsValid(oldline) then oldline:SetColumnText(2, "") end
				
				self.SelectedLeft = cvl:GetString()
				
				local newline = self.SelectedLeft and self.Lines[self.SelectedLeft]
				if IsValid(newline) then newline:SetColumnText(2, "X") end
			end
			
			if self.SelectedRight ~= cvr:GetString() then
				local oldline = self.SelectedRight and self.Lines[self.SelectedRight]
				if IsValid(oldline) then oldline:SetColumnText(3, "") end
				
				self.SelectedRight = cvr:GetString()
				
				local newline = self.SelectedRight and self.Lines[self.SelectedRight]
				if IsValid(newline) then newline:SetColumnText(3, "X") end
			end
		end
		
		panel:AddItem(listbox)
		
		panel:CheckBox("Show Compass", "nav_show_compass")
		panel:CheckBox("Drop created areas to the ground", "nav_create_place_on_ground")
		
		panel:Button("Compress Nav area IDs", "nav_compress_id")
		panel:ControlHelp("Optimizes the Navmesh by re-numbering them so that there are no gaps in their IDs. Should be done after editing, before saving.")
		
		local d = vgui.Create("DPanel", panel)
		d:Dock(TOP)
		d:DockMargin(5,15,5,5)
		d:SetBackgroundColor(Color(240,240,240))
		d.AddItem = DForm.AddItem
		d.Items = {}
		function d:PerformLayout() self:SizeToChildren(false,true) end
		
		local lbl = d:Add("DLabel")
		lbl:SetText("Save/Load")
		lbl:SetTextColor(Color(255,50,20))
		lbl:SetFont("Trebuchet18")
		lbl:SetContentAlignment(5)
		lbl:Dock(TOP)
		lbl:SizeToContentsY()
		d.Items[1] = lbl
		
		local b = panel.Button(d, "Save for nZombies")
		b.DoClick = nzu.RequestNavmeshSave
		panel.ControlHelp(d, "Saves the Navmesh in a separate file that only nZombies Unlimited will load for this specific Config")
		
		local warn = panel.Help(d, "Warning! - These will do permanent changes to the Navmesh."):SetTextColor(Color(255,50,20))
		
		local buts = {}
		local loadnzu = panel.Button(d, "Load nZombies Navmesh")
		loadnzu.DoClick = nzu.RequestNavmeshLoad
		table.insert(buts, loadnzu)
		panel.ControlHelp(d, "Loads the nZombies-specific Navmesh file for this Config")
		
		table.insert(buts, panel.Button(d, "Clear all Nav areas", "nav_reset"))
		panel.ControlHelp(d, "Will delete every single area")
		table.insert(buts, panel.Button(d, "Load last saved version", "nav_load"))
		panel.ControlHelp(d, "Restores the Navmesh to the last saved global version")
		table.insert(buts, panel.Button(d, "Save to global Navmesh file", "nav_save"))
		panel.ControlHelp(d, "Saves the Navmesh to the global version. This version is loaded in all gamemodes, so ensure it has no nZombies-specific modifications!")
		
		local chk = panel.CheckBox(d, "Confirm dangerous commands")
		chk.OnChange = function(s,b) for k,v in pairs(buts) do v:SetEnabled(b) end end
		for k,v in pairs(buts) do v:SetEnabled(false) end
		
		d:InvalidateLayout(true)
	end
end

nzu.RegisterTool("naveditor", TOOL)