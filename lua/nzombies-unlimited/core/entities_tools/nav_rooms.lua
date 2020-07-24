local rooms = {}
local area_reference = {}

local TOOL = {}
TOOL.Category = "Navigation"
TOOL.Name = "#tool.nzu_tool_navrooms.name"

TOOL.nzu_NavEdit = true

TOOL.ClientConVar = {
	["room"] = "",
}

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
		if self:GetStage() == 2 then
			local area = navmesh.GetNearestNavArea(navmesh.GetEditCursorPosition())
			if IsValid(area) then
				if self.MarkedRoom[area:GetID()] then self.MarkedRoom[area:GetID()] = nil else self.MarkedRoom[area:GetID()] = area end
			end
		else
			local area = navmesh.GetNearestNavArea(navmesh.GetEditCursorPosition())
			if not self.MarkedConnections then self.MarkedConnections = {} end
			if self.MarkedConnections[area:GetID()] then self.MarkedConnections[area:GetID()] = nil else self.MarkedConnections[area:GetID()] = area end

			self:SetStage(1)
		end
	end
	return true
end

function TOOL:RightClick(trace)
	if SERVER then
		if self:GetStage() == 0 then
			local area = navmesh.GetNearestNavArea(navmesh.GetEditCursorPosition())
			if IsValid(area) and area_reference[area:GetID()] then
				self.MarkedRoom = area_reference[area:GetID()]
				self:SetStage(2)
			--else
				--self.MarkedRoom = {}
				--self:SetStage(2)
			end
		elseif self:GetStage() == 1 then
			local start = navmesh.GetNearestNavArea(navmesh.GetEditCursorPosition())
			if IsValid(start) then
				if not self.MarkedConnections then self.MarkedConnections = {} end
				local areas = {}

				local recursive
				local count = 0
				recursive = function(area)
					if not areas[area:GetID()] and not self.MarkedConnections[area:GetID()] then
						areas[area:GetID()] = area
						count = count + 1
						for k,v in pairs(area:GetAdjacentAreas()) do
							recursive(v)
							if count > 100 then break end -- We limit here. Players should be wary it doesn't take this many nav areas. Manual addition can be used if needed.
						end
					end
				end
				recursive(start)

				self.MarkedRoom = areas
				self:SetStage(2)
			end
		else
			self.MarkedRoom = nil
			self:SetStage(1)
		end
	end

	return true
end

function TOOL:Reload(trace)
	if SERVER then
		self.MarkedConnections = nil
		self.MarkedRoom = nil

		self:SetStage(0)
	end
	return true
end

local connection_color = Color(0,255,0, 200)
local room_color = Color(0,0,255, 200)
function TOOL:Think()
	if SERVER then
		if self.MarkedConnections then
			for k,v in pairs(self.MarkedConnections) do
				--v:Draw()
				debugoverlay.Box(v:GetCorner(0), Vector(v:GetSizeX(), v:GetSizeY(), 0), Vector(0,0,0), 0.1, connection_color)
			end
		end

		if self.MarkedRoom then
			for k,v in pairs(self.MarkedRoom) do
				--v:Draw()
				debugoverlay.Box(v:GetCorner(0), Vector(v:GetSizeX(), v:GetSizeY(), 0), Vector(0,0,0), 0.1, room_color)
			end
		end
		--self:NextThink(CurTime() + 1)
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left", stage = 0},
		{name = "right", stage = 0},

		{name = "left_connection", stage = 1},
		{name = "right_create", stage = 1},
		{name = "reload", stage = 1},

		{name = "left_toggle", stage = 2},
		{name = "right_back", stage = 2},
		{name = "reload", stage = 2},
	}

	language.Add("tool.nzu_tool_navrooms.name", "Nav Rooms Editor")
	language.Add("tool.nzu_tool_navrooms.desc", "Associate Navmeshes to Room names. Any entities inside these navmeshes belong to this room.")

	language.Add("tool.nzu_tool_navrooms.left", "Begin new Room")
	language.Add("tool.nzu_tool_navrooms.right", "Edit existing Room")

	language.Add("tool.nzu_tool_navrooms.left_connection", "Toggle whether Navmesh is a Border")
	language.Add("tool.nzu_tool_navrooms.right_create", "Generate Room inside Borders")
	language.Add("tool.nzu_tool_navrooms.reload", "Cancel")

	language.Add("tool.nzu_tool_navrooms.left_toggle", "Toggle whether Navmesh is part of the Room")
	language.Add("tool.nzu_tool_navrooms.right_back", "Redo Borders")

	-- The Panel tutorial
	language.Add("tool.nzu_tool_navrooms.guide1", "Rooms are ")
	language.Add("tool.nzu_tool_navrooms.guide2", "A locked Nav Area is DISCONNECTED from its outgoing connections in nZombies Unlimited. Those locked with a Door Group are reconnected once the door opens, whereas those locked permanently are never reconnected.")
	language.Add("tool.nzu_tool_navrooms.guide3", "Nav Areas retain their INCOMING connections. This means Zombies can still reach inside, but they cannot navigate THROUGH.")

	language.Add("tool.nzu_tool_navrooms.clear", "The button below will clear all Nav Locks.")

	language.Add("tool.nzu_tool_navrooms.button_clear", "Clear all Nav Locks")
	language.Add("tool.nzu_tool_navrooms.button_confirm", "Are you sure?")

	function TOOL.BuildCPanel(panel)
		local header = panel:Help("Nav Locks")
		header:SetFont("DermaLarge")

		panel:Help("#tool.nzu_tool_navrooms.guide1")
		panel:Help("#tool.nzu_tool_navrooms.guide2")
		panel:Help("#tool.nzu_tool_navrooms.guide3")

		panel:Help("#tool.nzu_tool_navrooms.clear")
		local but = vgui.Create("DButton", panel)
		but.Think = function(s)
			if s.ResetTime and s.ResetTime < CurTime() then
				s:SetText("#tool.nzu_tool_navrooms.button_clear")
				s.ResetTime = nil
			end
		end

		but.DoClick = function(s)
			if not s.ResetTime then
				s:SetText("#tool.nzu_tool_navrooms.button_confirm")
				s.ResetTime = CurTime() + 5
			else
				net.Start("nzu_navlock_clear")
				net.SendToServer()

				s:SetText("#tool.nzu_tool_navrooms.button_clear")
				s.ResetTime = nil
			end
		end
		but:SetText("#tool.nzu_tool_navrooms.button_clear")

		panel:AddItem(but)
	end
end

nzu.RegisterTool("navrooms", TOOL)