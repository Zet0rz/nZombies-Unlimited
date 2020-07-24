
local outofbounds

if SERVER then
	outofbounds = {}

	-- Functions for the gamemode
	function nzu.IsNavOutOfBounds(area)
		return outofbounds[area:GetID()]
	end
	function nzu.IsNavIDOutOfBounds(id)
		return outofbounds[id]
	end

	-- Saving! Man, isn't it just easy?
	nzu.AddSaveExtension("NavOutOfBounds", {
		Save = function()
			local tbl = {OutOfBounds = table.GetKeys()}
			return tbl
		end,
		Load = function(data)
			outofbounds = {}
			local towarn = false

			if NZU_NZOMBIES then
				for k,v in pairs(data.OutOfBounds) do
					outofbounds[v] = true
				end
			else
				for k,v in pairs(data.OutOfBounds) do
					local area = navmesh.GetNavAreaByID(v)
					if IsValid(area) then
						outofbounds[v] = area
					else
						towarn = true
					end
				end
			end

			if towarn then
				PrintMessage(HUD_PRINTTALK, "Warning: The map appears to have a different Navmesh from the last save of this Config. This could interfere with Out of Bounds marks. Use the Nav Locker tool to clear all data if it needs to be redone.")
			end
		end
	})

	if NZU_SANDBOX then
		util.AddNetworkString("nzu_navoutofbounds_clear") -- Client: Request server wiping current locks
		net.Receive("nzu_navoutofbounds_clear", function(len, ply)
			--if nzu.IsAdmin(ply) then
				outofbounds = {}

				PrintMessage(HUD_PRINTTALK, "Out of Bounds marks cleared by "..ply:Nick())
			--end
		end)
	end
end

if NZU_NZOMBIES then return end -- No more here!

local TOOL = {}
TOOL.Category = "Navigation"
TOOL.Name = "#tool.nzu_tool_navoutofbounds.name"

TOOL.nzu_NavEdit = true

-- Enable nav_edit on deploy, only if admin or it's not already enabled
function TOOL:Deploy()
	if SERVER and not GetConVar("nav_edit"):GetBool() then
		if nzu.IsAdmin(self:GetOwner()) then
			RunConsoleCommand("nav_edit", "1")
		else
			self:GetOwner():ChatPrint("You can only use this tool while nav_edit is set to 1. Admins may do this in the server console, or by deploying this tool.")
		end
	end
end

-- Disable nav_edit on holster, only if it is already enabled and no other players hold an editing tool
function TOOL:Holster()
	if SERVER and GetConVar("nav_edit"):GetBool() then
		for k,v in pairs(player.GetAll()) do
			if v ~= self:GetOwner() and v:Alive() and nzu.IsAdmin(v) then
				local tool = v:GetTool()
				if tool and tool.nzu_NavEdit then return true end
			end
		end
		RunConsoleCommand("nav_edit", "0")
	end
	return true
end

function TOOL:LeftClick(trace)
	if SERVER then
		if self:GetStage() == 0 then
			local nav = navmesh.GetNearestNavArea(trace.HitPos)
			if IsValid(nav) then
				if outofbounds[nav:GetID()] then outofbounds[nav:GetID()] = nil else outofbounds[nav:GetID()] = nav end
			end
		else
			local nav = navmesh.GetNearestNavArea(trace.HitPos)
			if IsValid(nav) then
				local toggle = outofbounds[nav:GetID()] and true or false

				local recursive
				local count = 0
				local found = {}
				recursive = function(area)
					local exists = outofbounds[area:GetID()] and true or false
					if toggle == exists and not found[area:GetID()] then
						found[area:GetID()] = true
						if exists then outofbounds[area:GetID()] = nil else outofbounds[area:GetID()] = area end
						count = count + 1

						if not self.BorderMarks[area:GetID()] then
							for k,v in pairs(area:GetAdjacentAreas()) do
								recursive(v)
								if count > 20 then break end -- We limit here. Players should be wary it doesn't take this many nav areas. Manual addition can be used if needed.
							end
						end
					end
				end
				recursive(nav)

				self.BorderMarks = nil
				self:SetStage(0)
			end
		end
	end
	return true
end

function TOOL:RightClick(trace)
	if SERVER then
		local nav = navmesh.GetNearestNavArea(trace.HitPos)
		if IsValid(nav) then
			if not self.BorderMarks then
				self.BorderMarks = {[nav:GetID()] = nav}
				self:SetStage(1)
			elseif self.BorderMarks[nav:GetID()] then
				self.BorderMarks[nav:GetID()] = nil
				if table.IsEmpty(self.BorderMarks) then
					self.BorderMarks = nil
					self:SetStage(0)
				end
			else
				self.BorderMarks[nav:GetID()] = nav
			end
		end
	end
	return true
end

function TOOL:Reload(trace)
	if self:GetStage() == 1 then
		if SERVER then
			self.BorderMarks = nil
			self:SetStage(0)
		end
		return true
	end
end

if SERVER then
	local room_color = Color(0,0,255, 100)
	local outofbounds_color = Color(255,0,0, 100)
	function TOOL:Think()
		--if GetConVar("nav_edit"):GetBool() then
			local area = navmesh.GetNearestNavArea(self:GetOwner():GetEyeTrace().HitPos)

			local wep = self:GetWeapon()
			if IsValid(area) and outofbounds[area:GetID()] then
				if not wep:GetNW2Bool("nzu_navmarked") then wep:SetNW2Bool("nzu_navmarked", true) end
			else
				if wep:GetNW2Bool("nzu_navmarked") then wep:SetNW2Bool("nzu_navmarked", nil) end
			end
		--end

		if self.BorderMarks then
			for k,v in pairs(self.BorderMarks) do
				--v:Draw()
				debugoverlay.Box(v:GetCorner(0), Vector(v:GetSizeX(), v:GetSizeY(), 0), Vector(0,0,0), 0.1, room_color)
			end
		end

		for k,v in pairs(outofbounds) do
			debugoverlay.Box(v:GetCorner(0), Vector(v:GetSizeX(), v:GetSizeY(), 0), Vector(0,0,0), 0.1, outofbounds_color)
		end
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left", stage = 0},
		{name = "right", stage = 0},

		{name = "left_borderfill", stage = 1},
		{name = "right_border", stage = 1},
		{name = "reload", stage = 1},
	}

	language.Add("tool.nzu_tool_navoutofbounds.name", "Out of Bounds Marker")
	language.Add("tool.nzu_tool_navoutofbounds.desc", "Marks Nav Areas to be treated as outside playable area in nZombies Unlimited.")

	language.Add("tool.nzu_tool_navoutofbounds.left", "Toggle Navmesh being Out of Bounds")
	language.Add("tool.nzu_tool_navoutofbounds.right", "Create border for flood marking")

	language.Add("tool.nzu_tool_navoutofbounds.left_borderfill", "Flood mark all Navmeshes from this within border marks")
	language.Add("tool.nzu_tool_navoutofbounds.right_border", "Toggle Navmesh being border for Out of Bounds flood mark")
	language.Add("tool.nzu_tool_navoutofbounds.reload", "Cancel")

	-- The Panel tutorial
	language.Add("tool.nzu_tool_navoutofbounds.guide1", "Marking areas as Out of Bounds can be used by the gamemode to determine areas that players cannot (under normal circumstances) reach.")
	language.Add("tool.nzu_tool_navoutofbounds.guide2", "This is for example used to make Powerups not drop from zombies killed outside playable area.")
	language.Add("tool.nzu_tool_navoutofbounds.guide3", "Turn on 'developer 1' in console to see marked Navmeshes in the world.")

	language.Add("tool.nzu_tool_navoutofbounds.clear", "The button below will clear all Marks.")

	language.Add("tool.nzu_tool_navoutofbounds.button_clear", "Clear all Out of Bounds Marks")
	language.Add("tool.nzu_tool_navoutofbounds.button_confirm", "Are you sure?")

	function TOOL.BuildCPanel(panel)
		local header = panel:Help("Out of Bounds Marks")
		header:SetFont("DermaLarge")

		panel:Help("#tool.nzu_tool_navoutofbounds.guide1")
		panel:Help("#tool.nzu_tool_navoutofbounds.guide2")
		panel:Help("#tool.nzu_tool_navoutofbounds.guide3")

		panel:Help("#tool.nzu_tool_navoutofbounds.clear")
		local but = vgui.Create("DButton", panel)
		but.Think = function(s)
			if s.ResetTime and s.ResetTime < CurTime() then
				s:SetText("#tool.nzu_tool_navoutofbounds.button_clear")
				s.ResetTime = nil
			end
		end

		but.DoClick = function(s)
			if not s.ResetTime then
				s:SetText("#tool.nzu_tool_navoutofbounds.button_confirm")
				s.ResetTime = CurTime() + 5
			else
				net.Start("nzu_navoutofbounds_clear")
				net.SendToServer()

				s:SetText("#tool.nzu_tool_navoutofbounds.button_clear")
				s.ResetTime = nil
			end
		end
		but:SetText("#tool.nzu_tool_navoutofbounds.button_clear")

		panel:AddItem(but)
	end

	local textcolor = Color(255,100,100)
	function TOOL:DrawToolScreen(w,h)
		local wep = self:GetWeapon()
		if wep:GetNW2Bool("nzu_navmarked") then
			draw.SimpleTextOutlined("Outside", "DermaLarge", w/2, 130, textcolor, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
		else
			draw.SimpleTextOutlined("Inside", "DermaLarge", w/2, 130, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
		end
	end
end

nzu.RegisterTool("navoutofbounds", TOOL)