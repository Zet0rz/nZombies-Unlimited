local ENT = {}

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.Model = "models/nzprops/zombies_power_lever.mdl"
ENT.HandleModel = "models/nzprops/zombies_power_lever_handle.mdl"

-- Why not also allow it to be spawned in the normal Entities menu?
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Electricity Switch"
ENT.Author = "Zet0r"
ENT.Spawnable = true

util.PrecacheModel(ENT.Model)
util.PrecacheModel(ENT.HandleModel)

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/nzprops/zombies_power_lever.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetUseType(ONOFF_USE)

		if NZU_NZOMBIES then nzu.ElectricityStartOff() end -- Notify server that electricity should start off
	else
		self.HandleSwitched = false
	end
end

if SERVER and NZU_NZOMBIES then
	function ENT:Use(activator)
		if not self:HasElectricity() and not nzu.Electricity() then
			nzu.TurnOnElectricity()
		end
	end
end

if CLIENT then
	function ENT:GetHandleAttachment()
		local ang = self:GetAngles()
		local pos = self:GetPos() + ang:Up()*46 + ang:Forward()*7
		return pos,ang
	end

	if NZU_NZOMBIES then
		local onang = Angle(0,0,0)
		local offang = Angle(-90,0,0)
		local switchtime = 1
		function ENT:DoHandleSwitch()
			if not self.SwitchStartTime then self.SwitchStartTime = CurTime() end
			local lerp = math.Clamp((CurTime() - self.SwitchStartTime)/switchtime, 0, 1)

			local ang
			if nzu.Electricity() then
				ang = LerpAngle(lerp, offang, onang)
			else
				ang = LerpAngle(lerp, onang, offang)
			end

			self.Handle:SetAngles(self:LocalToWorldAngles(ang))
			if lerp >= 1 then
				self.HandleSwitched = nzu.Electricity()
				self.SwitchStartTime = nil
			end
		end
		function ENT:Think()
			if not IsValid(self.Handle) then
				self.Handle = ClientsideModel(self.HandleModel)
				local pos,ang = self:GetHandleAttachment()
				self.Handle:SetPos(pos)
				self.Handle:SetAngles(ang)
				self.Handle:SetParent(self)
			end

			if self.HandleSwitched ~= nzu.Electricity() then
				self:DoHandleSwitch()
			end
		end
	else
		function ENT:Think()
			if not IsValid(self.Handle) then
				self.Handle = ClientsideModel(self.HandleModel)
				local pos,ang = self:GetHandleAttachment()
				self.Handle:SetPos(pos)
				self.Handle:SetAngles(ang)
				self.Handle:SetParent(self)
			end
		end
	end	
	
	function ENT:OnRemove()
		if IsValid(self.Handle) then
			self.Handle:Remove()
			self.Handle = nil
		end
	end
end
scripted_ents.Register(ENT, "nzu_electricityswitch")

--[[-------------------------------------------------------------------------
Tool for creating switch
---------------------------------------------------------------------------]]
local TOOL = {}
TOOL.Category = "Basic"
TOOL.Name = "#tool.nzu_tool_electricityswitch.name"

function TOOL:LeftClick(trace)
	if SERVER then
		local ply = self:GetOwner()
		local e = ents.Create("nzu_electricityswitch")
		e:SetPos(trace.HitPos)
		e:SetAngles(Angle(0,(ply:GetPos() - trace.HitPos):Angle()[2],0))
		e:Spawn()
		
		if IsValid(ply) then
			undo.Create("Electricity Switch")
				undo.SetPlayer(ply)
				undo.AddEntity(e)
			undo.Finish()
		end
		return true
	end
end

function TOOL:RightClick(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_electricityswitch" then
		trace.Entity:Remove()
		return true
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left"},
		{name = "right"},
	}

	language.Add("tool.nzu_tool_electricityswitch.name", "Electricity Switch")
	language.Add("tool.nzu_tool_electricityswitch.desc", "Creates an Electricity Switch that will turn on global electricity when used.")

	language.Add("tool.nzu_tool_electricityswitch.left", "Create Electricity Switch")
	language.Add("tool.nzu_tool_electricityswitch.right", "Remove Electricity Switch")

	function TOOL.BuildCPanel(panel)
		panel:Help("Spawn an Electricity Switch that will turn on the global electricity state when used in-game.")
	end
end

nzu.RegisterTool("electricityswitch", TOOL)