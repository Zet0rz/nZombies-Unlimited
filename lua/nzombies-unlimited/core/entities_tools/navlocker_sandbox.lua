
local navdoors = {}
local navblocks = {}

local function locknavarea(a, group)
	navdoors[a:GetID()] = group
end
local function blocknavarea(a)
	navblocks[a:GetID()] = true
end

function nzu.LockNavArea(a, group)
	if group then locknavarea(a, group) else blocknavarea(a) end
end

if SERVER then
	-- Saving! Man, isn't it just easy?
	nzu.AddSaveExtension("NavLocks", {
		Save = function()
			local tbl = {NavDoors = navdoors, NavBlocks = navblocks, Count = navmesh.GetNavAreaCount()}
			return tbl
		end,
		Load = function(data)
			navdoors = data.NavDoors
			navblocks = data.NavBlocks

			if navmesh.GetNavAreaCount() ~= data.Count then
				PrintMessage(HUD_PRINTTALK, "Warning: The map appears to have a different Navmesh from the last save of this Config. This could interfere with Navlocks. Use the Nav Locker tool to clear all data if it needs to be redone.")
			end
		end
	})

	util.AddNetworkString("nzu_navlock_clear") -- Client: Request server wiping current locks
	net.Receive("nzu_navlock_clear", function(len, ply)
		--if nzu.IsAdmin(ply) then
			navdoors = {}
			navblocks = {}

			PrintMessage(HUD_PRINTTALK, "Nav Locks cleared by "..ply:Nick())
		--end
	end)
end

--[[-------------------------------------------------------------------------
The tool to do the magic
---------------------------------------------------------------------------]]

local TOOL = {}
TOOL.Category = "Navigation"
TOOL.Name = "#tool.nzu_tool_navlock.name"

TOOL.nzu_NavEdit = true

TOOL.ClientConVar = {
	["group"] = "",
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

function TOOL:LeftClick(trace)	
	if self:GetStage() == 0 then
		if IsValid(trace.Entity) then
			local data = trace.Entity:GetDoorData()
			if data and data.Group and data.Group ~= "" then
				if SERVER then
					self:GetOwner():ConCommand("nzu_tool_navlock_group "..data.Group)
					self:SetStage(1)
				end
				return true
			elseif SERVER then
				self:GetOwner():ChatPrint("This entity has no Door Group set.")
			end
		end
	elseif self:GetStage() == 1 then
		local group = self:GetClientInfo("group")
		if group and group ~= "" then
			if SERVER then
				local nav = navmesh.GetNearestNavArea(trace.HitPos)
				if IsValid(nav) then
					locknavarea(nav, group)
					self:SetStage(0)
				end
			end
			return true
		elseif SERVER then
			self:GetOwner():ChatPrint("Invalid Door Group. Did you change it in console?")
			self:SetStage(0)
		end
	end
end

-- Permanently blocks area
function TOOL:RightClick(trace)
	if SERVER then
		local nav = navmesh.GetNearestNavArea(trace.HitPos)
		if IsValid(nav) then
			blocknavarea(nav, group)
		end
	end
	return true
end

-- Cancels if mid-operation, removes lock if not
function TOOL:Reload(trace)
	if SERVER then
		if self:GetStage() ~= 0 then
			self:SetStage(0)
		else
			local nav = navmesh.GetNearestNavArea(trace.HitPos)
			if IsValid(nav) then
				local id = nav:GetID()
				navdoors[id] = nil
				navblocks[id] = nil
			end
		end
	end
	return true
end

if SERVER then
	function TOOL:Think()
		if GetConVar("nav_edit"):GetBool() then
			local area = navmesh.GetNearestNavArea(self:GetOwner():GetEyeTrace().HitPos)

			local wep = self:GetWeapon()
			if IsValid(area) then
				local nav = area:GetID()
				if navblocks[nav] then
					if not wep:GetNW2Bool("nzu_navblocked") then wep:SetNW2Bool("nzu_navblocked", true) end
					if wep:GetNW2String("nzu_navlocked") then wep:SetNW2String("nzu_navlocked", nil) end
				elseif navdoors[nav] then
					if wep:GetNW2String("nzu_navlocked") ~= navdoors[nav] then wep:SetNW2String("nzu_navlocked", navdoors[nav]) end
				else
					if wep:GetNW2Bool("nzu_navblocked") then wep:SetNW2Bool("nzu_navblocked", nil) end
					if wep:GetNW2String("nzu_navlocked") then wep:SetNW2String("nzu_navlocked", nil) end
				end
			else
				if wep:GetNW2Bool("nzu_navblocked") then wep:SetNW2Bool("nzu_navblocked", nil) end
				if wep:GetNW2String("nzu_navlocked") then wep:SetNW2String("nzu_navlocked", nil) end
			end
		end
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left", stage = 0},
		{name = "right", stage = 0},
		{name = "reload", stage = 0},

		{name = "left_nav", stage = 1},
		{name = "reload_cancel", stage = 1},
	}

	language.Add("tool.nzu_tool_navlock.name", "Nav Locker")
	language.Add("tool.nzu_tool_navlock.desc", "Marks Nav Areas to be disconnected in nZombies Unlimited under specific conditions.")

	language.Add("tool.nzu_tool_navlock.left", "Select Door")
	language.Add("tool.nzu_tool_navlock.right", "Create permanent Lock")
	language.Add("tool.nzu_tool_navlock.reload", "Remove Lock")

	language.Add("tool.nzu_tool_navlock.left_nav", "Select Nav Area")
	language.Add("tool.nzu_tool_navlock.reload_cancel", "Cancel")

	-- The Panel tutorial
	language.Add("tool.nzu_tool_navlock.guide1", "Nav Locks are how Zombies know not to navigate through doors that haven't been bought.")
	language.Add("tool.nzu_tool_navlock.guide2", "A locked Nav Area is DISCONNECTED from its outgoing connections in nZombies Unlimited. Those locked with a Door Group are reconnected once the door opens, whereas those locked permanently are never reconnected.")
	language.Add("tool.nzu_tool_navlock.guide3", "Nav Areas retain their INCOMING connections. This means Zombies can still reach inside, but they cannot navigate THROUGH.")

	language.Add("tool.nzu_tool_navlock.clear", "The button below will clear all Nav Locks.")

	language.Add("tool.nzu_tool_navlock.button_clear", "Clear all Nav Locks")
	language.Add("tool.nzu_tool_navlock.button_confirm", "Are you sure?")

	function TOOL.BuildCPanel(panel)
		local header = panel:Help("Nav Locks")
		header:SetFont("DermaLarge")

		panel:Help("#tool.nzu_tool_navlock.guide1")
		panel:Help("#tool.nzu_tool_navlock.guide2")
		panel:Help("#tool.nzu_tool_navlock.guide3")

		panel:Help("#tool.nzu_tool_navlock.clear")
		local but = vgui.Create("DButton", panel)
		but.Think = function(s)
			if s.ResetTime and s.ResetTime < CurTime() then
				s:SetText("#tool.nzu_tool_navlock.button_clear")
				s.ResetTime = nil
			end
		end

		but.DoClick = function(s)
			if not s.ResetTime then
				s:SetText("#tool.nzu_tool_navlock.button_confirm")
				s.ResetTime = CurTime() + 5
			else
				net.Start("nzu_navlock_clear")
				net.SendToServer()

				s:SetText("#tool.nzu_tool_navlock.button_clear")
				s.ResetTime = nil
			end
		end
		but:SetText("#tool.nzu_tool_navlock.button_clear")

		panel:AddItem(but)
	end

	local permalock = Color(255,100,100)
	local grouplock = Color(100,100,255)
	function TOOL:DrawToolScreen(w,h)
		local str = self:GetStage() == 0 and "Select a Door" or "Selected: "..(self:GetClientInfo("group") or "")
		draw.SimpleTextOutlined(str, "DermaLarge", w/2, 100, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)

		local wep = self:GetWeapon()
		if wep:GetNW2Bool("nzu_navblocked") then
			draw.SimpleTextOutlined("Permanent Lock", "ChatFont", w/2, 130, permalock, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
		else
			local str2 = wep:GetNW2String("nzu_navlocked", nil)
			if str2 and str2 ~= "" then
				draw.SimpleTextOutlined("Group: "..str2, "DermaLarge", w/2, 130, grouplock, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
			else
				draw.SimpleTextOutlined("No Lock found", "ChatFont", w/2, 130, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
			end
		end
	end
end

nzu.RegisterTool("navlock", TOOL)