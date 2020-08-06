local ENT = {}

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.Model = Model("models/nzu/electricityswitch/zombies_power_lever.mdl")
ENT.HandleModel = Model("models/nzu/electricityswitch/zombies_power_lever_handle.mdl")

-- Why not also allow it to be spawned in the normal Entities menu?
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Electricity Switch"
ENT.Author = "Zet0r"
ENT.Spawnable = true

util.PrecacheModel(ENT.Model)
util.PrecacheModel(ENT.HandleModel)

function ENT:Initialize()
	if SERVER then
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(ONOFF_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end

		hook.Add("nzu_ShouldElectricityStartOff", self, function() return true end) -- Start electricity off if we're valid (hook only runs if self is valid)
	else
		self.HandleSwitched = false
	end
end

if SERVER and NZU_NZOMBIES then
	local powersound = Sound("nzu/power/power_on.wav")
	function ENT:Use(activator)
		if not self:HasElectricity() and not nzu.Electricity() then
			nzu.TurnOnElectricity()
			self:EmitSound(powersound)
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
			if self:HasElectricity() then
				ang = LerpAngle(lerp, onang, offang)
			else
				ang = LerpAngle(lerp, offang, onang)
			end

			self.Handle:SetAngles(self:LocalToWorldAngles(ang))
			if lerp >= 1 then
				self.HandleSwitched = self:HasElectricity()
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

			if self.HandleSwitched ~= self:HasElectricity() then
				self:DoHandleSwitch()
			end
		end

		function ENT:GetTargetIDText()
			if not self:HasElectricity() then
				return "Use", "turn on Electricity"
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

	function ENT:Draw()
		self:DrawModel()
	end
end
scripted_ents.Register(ENT, "nzu_electricityswitch")

--[[-------------------------------------------------------------------------
Tool for creating switch
---------------------------------------------------------------------------]]
if NZU_SANDBOX then
	local TOOL = {}
	TOOL.Category = "Power"
	TOOL.Name = "#tool.nzu_tool_electricityswitch.name"

	function TOOL:LeftClick(trace)
		if SERVER then
			local ply = self:GetOwner()

			local tr = util.TraceLine({
				start = trace.HitPos + trace.HitNormal,
				endpos = trace.HitPos + trace.HitNormal + Vector(0,0,-100),
				filter = ply,
			})

			local pos = tr.Hit and tr.HitPos or trace.HitPos
			local ang = trace.HitNormal:Angle()

			local e = ents.Create("nzu_electricityswitch")
			e:SetPos(pos)
			e:SetAngles(ang)
			e:Spawn()
			
			if IsValid(ply) then
				undo.Create("Electricity Switch")
					undo.SetPlayer(ply)
					undo.AddEntity(e)
				undo.Finish()
			end
		end
		return true
	end

	function TOOL:RightClick(trace)
		if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_electricityswitch" then
			if SERVER then trace.Entity:Remove() end
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
end