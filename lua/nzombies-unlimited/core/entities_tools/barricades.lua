local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"

-- Allow spawnmenu too
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Barricade"
ENT.Author = "Zet0r"
ENT.Spawnable = true
--ENT.Editable = true

if SERVER then
	AccessorFunc(ENT, "m_iMaxPlanks", "MaxPlanks", FORCE_NUMBER)
	AccessorFunc(ENT, "m_fPlankRepairTime", "PlankRepairTime", FORCE_NUMBER)
	AccessorFunc(ENT, "m_fPlankTearTime", "PlankTearTime", FORCE_NUMBER)
	AccessorFunc(ENT, "m_bTriggerVault", "TriggerVault", FORCE_NUMBER)
end

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsClear")
	self:NetworkVar("Bool", 1, "CanBeRepaired")
	self:NetworkVar("Int", 0, "PlankCount")
end

local model = Model("models/props_c17/fence01b.mdl")
function ENT:Initialize()
	if SERVER then
		self:SetModel(model)
		--self:SetNoDraw(NZU_NZOMBIES) -- Don't draw in nZombies
		self:PhysicsInit(SOLID_VPHYSICS)

		self.m_iNumPlanks = 0
		self.m_iNumBlockingPlanks = 0
		self.m_tPlanks = {}
		self.m_tReservedSpots = {}

		if not self:GetMaxPlanks() then self:SetMaxPlanks(6) end
		if not self:GetPlankRepairTime() then self:SetPlankRepairTime(1) end
		if not self:GetPlankTearTime() then self:SetPlankTearTime(3) end

		for i = 1, self:GetMaxPlanks() do
			timer.Simple(i * 0.1, function()
				--if IsValid(self) then self:RepairPlank() end
			end)
		end

		self:SetCanBeRepaired(true)
	end
end

if SERVER then
	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		
		local pos = tr.HitPos + tr.HitNormal * 45
		local ent = ents.Create(class)
		ent:SetPos(pos)
		ent:Spawn()
		ent:Activate()
		return ent
	end

	function ENT:RepairPlank(ply, plank)
		-- Get a broken plank to repair first
		if not IsValid(plank) then
			plank = self:GetBrokenPlank()
		end

		-- Add more planks if necessary
		if not IsValid(plank) then
			if self.m_iNumPlanks >= self:GetMaxPlanks() then return end
			plank = self:AddPlank()
		end

		-- Repair the found plank
		if IsValid(plank) and plank:GetBarricade() == self then
			plank:Repair(ply)
			return plank
		end
	end

	function ENT:AddPlank()
		local plank = ents.Create("nzu_barricade_plank")
		--plank:SetParent(self)
		plank:SetBarricade(self)
		plank:SetPlankRepairTime(self:GetPlankRepairTime())
		plank:SetPlankTearTime(self:GetPlankTearTime())

		-- Calculate position on barricade
		local pos,ang = self:GetPlankPosition(plank)
		plank:SetLocalPos(pos)
		plank:SetLocalAngles(ang)
		plank:Spawn()

		self.m_iNumPlanks = self.m_iNumPlanks + 1
		self.m_tPlanks[plank] = true

		return plank
	end

	function ENT:TearPlank(ent, plank)
		if not IsValid(plank) then
			plank = self:GetRepairedPlank()
		end

		if IsValid(plank) then
			plank:Tear(ent)
			return plank
		end
	end

	-- Return a random, repaired plank that isn't currently reserved by another entity
	function ENT:GetRepairedPlank()
		local tbl = {}
		for k,v in pairs(self.m_tPlanks) do
			if k:GetRepaired() and not IsValid(k.CurrentUser) then
				table.insert(tbl, k)
			end
		end

		return tbl[math.random(#tbl)]
	end

	-- Return a random broken plank that isn't currently being repaired by another entity
	function ENT:GetBrokenPlank()
		local tbl = {}
		for k,v in pairs(self.m_tPlanks) do
			if not k:GetRepaired() and not IsValid(k.CurrentUser) then
				table.insert(tbl, k)
			end
		end

		return tbl[math.random(#tbl)]
	end

	function ENT:HasAvailablePlanks()
		for k,v in pairs(self.m_tPlanks) do
			if k:GetRepaired() and not IsValid(k.CurrentUser) then
				return true
			end
		end
		return false
	end

	-- Reserves a plank so that no other entities can interact with this
	function ENT:StartTear(ent)
		local plank = self:GetRepairedPlank()
		if IsValid(plank) then
			plank.CurrentUser = ent
			self:InternalPlankStartTear(plank)
			return plank
		end
	end

	function ENT:GetPlankPosition(plank)
		return Vector(0,0,math.random(-5,40)), Angle(0,0,90 + math.random(-40,40))
	end

	function ENT:GetGroundPositionAwayFrom(ply)
		local mult = 1
		if IsValid(ply) and (ply:GetPos() - self:GetPos()):Dot(self:GetAngles():Forward()) > 0 then
			mult = -1
		end

		return Vector(75*mult, math.random(-10,10), -45)
	end

	function ENT:Use(activator)
		if self:GetCanBeRepaired() and (not self.NextRepair or self.NextRepair < CurTime()) then
			local plank = self:RepairPlank(activator)
			self.NextRepair = CurTime() + plank:GetPlankRepairTime() + 0.25
		end
	end

	function ENT:OnRemove()
		for k,v in pairs(self.m_tPlanks) do
			if IsValid(k) then k:Remove() end
		end
	end

	ENT.BarricadeTearPositions = {
		Front = {
			Vector(-33,0,-45),
			Vector(-33,35,-45),
			Vector(-33,-35,-45),
		},
		Back = {
			Vector(33,0,-45),
			Vector(33,35,-45),
			Vector(33,-35,-45),
		}
	}
	function ENT:ReserveAvailableTearPosition(z)
		local tbl = (z:GetPos() - self:GetPos()):Dot(self:GetAngles():Forward()) < 0 and self.BarricadeTearPositions.Front or self.BarricadeTearPositions.Back
		for k,v in pairs(tbl) do
			if not IsValid(self.m_tReservedSpots[v]) then
				self.m_tReservedSpots[v] = z
				return self:LocalToWorld(v)
			end
		end
	end

	function ENT:GetVaultPositions()
		return self:LocalToWorld(Vector(35,0,-45)), self:LocalToWorld(Vector(-35,0,-45))
	end

	--[[-------------------------------------------------------------------------
	Internal functions + callbacks
	---------------------------------------------------------------------------]]
	function ENT:InternalPlankStartTear(plank)

	end

	function ENT:InternalPlankFinishTear(plank)
		self.m_iNumBlockingPlanks = self.m_iNumBlockingPlanks - 1
		if self.m_iNumBlockingPlanks <= 0 then
			self:SetIsClear(true)
		end

		if not self:GetCanBeRepaired() then
			self:SetCanBeRepaired(true)
		end

		self:SetPlankCount(self:GetPlankCount() - 1)
	end

	function ENT:InternalPlankStartRepair(plank)
		self.m_iNumBlockingPlanks = self.m_iNumBlockingPlanks + 1
		if self:GetIsClear() then
			self:SetIsClear(false)
		end

		if self.m_iNumBlockingPlanks >= self:GetMaxPlanks() then
			self:SetCanBeRepaired(false)
		end
	end

	function ENT:InternalPlankFinishRepair(plank)
		self:SetPlankCount(self:GetPlankCount() + 1)
	end
	

	--[[-------------------------------------------------------------------------
	Zombie Event
	---------------------------------------------------------------------------]]

	-- By default, if BarricadeVault is not defined on the zombie, we SubEvent into normal Vault
	-- We calculate to and from here, but the Zombie can do that itself if it implements BarricadeVault
	local function triggervault(z, self)
		local from,to = self:GetVaultPositions()
		local tbl
		if z:GetPos():DistToSqr(from) < z:GetPos():DistToSqr(to) then
			tbl = {From = from, To = to}
		else
			tbl = {From = to, To = from}
		end
		z:SubEvent("Vault", nil, tbl) -- It's a SUB-event! This means the zombie's event is still "BarricadeVault", we just run the equivalent function
	end

	function ENT:ZombieInteract(z)
		if not self:GetIsClear() then
			z:TriggerEvent("BarricadeTear", self.DefaultZombieHandler, self)
		else
			if z:IsMovingTowards(self:GetPos()) then
				z:TriggerEvent("BarricadeVault", triggervault, self)
			end
		end
	end


	ENT.DefaultZombieHandler = function(self, barricade) -- self here is the zombie
		if not barricade:HasAvailablePlanks() then
			self:Timeout(2) -- Do nothing for 2 seconds
		return end

		local pos,index = barricade:ReserveAvailableTearPosition(self)
		if not pos then
			self:Timeout(2) -- Do nothing for 2 seconds
		return end

		-- We got a barricade position, move towards it
		self:SolidMaskDuringEvent(MASK_NPCSOLID_BRUSHONLY)
		local result = self:MoveToPos(pos, {lookahead = 20, tolerance = 20, maxage = 3, draw = true})
		if result == "ok" and not self:ShouldEventTerminate() then
			-- We're in position
			self:FaceTowards(barricade:GetPos())

			local planktotear = barricade:StartTear(self)
			while IsValid(planktotear) do
				local attack = self:SelectAttack(barricade)
				local impact = attack.Impacts[1]
				local seqdur = self:SequenceDuration(self:LookupSequence(attack.Sequence))
				local time = seqdur*impact

				self:Timeout(planktotear:GetPlankTearTime() - time) -- We wait as long so that the attack matches the tear time
				self:ResetSequence(attack.Sequence)

				coroutine.wait(time)

				barricade:TearPlank(self, planktotear)
				local phys = planktotear:GetPhysicsObject()
				if IsValid(phys) then
					local vec = self:GetPos() - planktotear:GetPos()
					vec.z = 0
					phys:SetVelocity(vec*2)
				end

				coroutine.wait(seqdur - time)

				if self:ShouldEventTerminate() then break end
				planktotear = barricade:StartTear(self)
			end
		else
			self:Timeout(2)
		end
		if barricade.m_tReservedSpots[pos] == self then barricade.m_tReservedSpots[pos] = nil end
	end
else
	function ENT:Draw() self:DrawModel() end

	function ENT:GetTargetIDText()
		if self:GetCanBeRepaired() then
			return " Repair Barricade ", TARGETID_TYPE_USE
		end
	end
end

local PLANK = {}
PLANK.Type = "anim"
PLANK.Base = "base_entity"
PLANK.Category = "nZombies Unlimited"
PLANK.PrintName = "Barricade Plank"
PLANK.Author = "Zet0r"

if SERVER then
	AccessorFunc(PLANK, "m_fPlankRipTime", "PlankRipTime", FORCE_NUMBER)
	AccessorFunc(PLANK, "m_fPlankRepairTime", "PlankRepairTime", FORCE_NUMBER)
	AccessorFunc(PLANK, "m_fPlankTearTime", "PlankTearTime", FORCE_NUMBER)
	AccessorFunc(PLANK, "m_eBarricade", "Barricade") -- Entity
end

PLANK.Model = Model("models/props_debris/wood_board02a.mdl")

function PLANK:SetupDataTables()
	self:NetworkVar("Bool", 0, "Repaired")
end

function PLANK:Initialize()
	if SERVER then
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	end
end

if SERVER then
	function PLANK:Repair(ply)
		if not self:GetRepaired() and not self.IsRepairing then
			local bar = self:GetBarricade()

			local gpos = bar:LocalToWorld(bar:GetGroundPositionAwayFrom(ply))
			self:SetPos(gpos)
			self:SetAngles(bar:LocalToWorldAngles(Angle(90,720,math.random(-30,30))))

			local pos,ang = bar:GetPlankPosition(self)

			self.TargetPos = pos
			self.TargetAng = ang
			self.TargetPos_W = bar:LocalToWorld(pos)
			self.TargetAng_W = bar:LocalToWorldAngles(ang)
			self.FloatPos = Vector(gpos.x, self.TargetPos_W.y, self.TargetPos_W.z)
			self.GroundPos = gpos

			local phys = self:GetPhysicsObject()
			if IsValid(phys) then
				phys:EnableGravity(false)
				phys:EnableCollisions(false)
				phys:Wake()
			end

			self.CurrentUser = ply

			self.IsRepairing = true
			self.RepairFinish = CurTime() + self:GetPlankRepairTime()
			self:StartMotionController()

			self:GetBarricade():InternalPlankStartRepair(self)
		end
	end

	function PLANK:Tear()
		self:SetParent(nil)
		self:SetRepaired(false)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
		end

		hook.Run("nzu_PlankTorn", self, self.CurrentUser)
		self.CurrentUser = nil

		self:GetBarricade():InternalPlankFinishTear(self)
	end

	function PLANK:OnRemove()
		local bar = self:GetBarricade()
		if IsValid(bar) and bar.m_tPlanks[self] then
			bar.m_iNumPlanks = bar.m_iNumPlanks - 1
			bar.m_tPlanks[self] = nil
		end
	end

	function PLANK:Think()
		if self.IsRepairing and self.RepairFinish <= CurTime() then
			self.IsRepairing = false
			self:SetRepaired(true)

			local phys = self:GetPhysicsObject()
			if IsValid(phys) then
				phys:EnableCollisions(true)
				phys:EnableGravity(true)
				phys:Sleep()
			end
			self:SetParent(self:GetBarricade())
			self:SetLocalPos(self.TargetPos)
			self:SetLocalAngles(self.TargetAng)

			self:StopMotionController()

			hook.Run("nzu_PlankRepaired", self, self.CurrentUser)

			self.TargetPos = nil
			self.TargetAng = nil
			self.TargetPos_W = nil
			self.TargetAng_W = nil
			self.FloatPos = nil
			self.GroundPos = nil
			self.CurrentUser = nil

			self:GetBarricade():InternalPlankFinishRepair(self)
		end
	end

	-- For custom animations reaching for the barricade. These should align with the plank's visual position and angle
	function PLANK:GetGrabPos() return self:GetPos() end
	function PLANK:GetGrabAngles() return self:GetAngles() end
else
	function PLANK:Draw()
		self:DrawModel()
	end
end

-- The rest of the time is spent floating by its position
PLANK.FlyUpTime = 0.3
PLANK.FlyInTime = 0.075
function PLANK:PhysicsSimulate(phys, dt)
	local diff = self.RepairFinish - CurTime()

	phys:Wake()

	local flyup = diff - self:GetPlankRepairTime() + self.FlyUpTime
	if flyup > 0 then
		local pct = math.Clamp(flyup/self.FlyUpTime, 0, 1)

		local lpos = LerpVector(pct, self.FloatPos, self.GroundPos)

		local ang = phys:GetAngles()
		local lang = LerpAngle(pct, self.TargetAng, ang)

		
		phys:SetPos(lpos)
		phys:SetAngles(lang)
		return
	end

	local flyin = self.FlyInTime - diff
	if flyin >= 0 then
		local pct = math.Clamp(flyin/self.FlyInTime, 0, 1)
		local lpos = LerpVector(pct, self.FloatPos, self.TargetPos_W)
		phys:SetPos(lpos)
	end
	return SIM_NOTHING
end

scripted_ents.Register(ENT, "nzu_barricade")
scripted_ents.Register(PLANK, "nzu_barricade_plank")