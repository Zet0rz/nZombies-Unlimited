local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"

-- Allow spawnmenu too
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Barricade"
ENT.Author = "Zet0r"
ENT.Spawnable = true
--ENT.Editable = true

ENT.RepairSound = "nzu_barricade_postrepair"
sound.Add({
	name = "nzu_barricade_postrepair",
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 80,
	pitch = {90,110},
	sound = "nzu/barricade/repair.wav"
})

if SERVER then
	AccessorFunc(ENT, "m_iMaxPlanks", "MaxPlanks", FORCE_NUMBER)
	AccessorFunc(ENT, "m_fPlankRepairTime", "PlankRepairTime", FORCE_NUMBER)
	AccessorFunc(ENT, "m_fPlankTearTime", "PlankTearTime", FORCE_NUMBER)
	AccessorFunc(ENT, "m_bTriggerVault", "TriggerVault", FORCE_BOOL)

	-- Ignore these fields in saving
	ENT.nzu_IgnoredFields = {
		["m_iNumBlockingPlanks"] = true,
		["m_tPlanks"] = true,
		["m_tReservedSpots"] = true,
	}

	-- What positions the barricade can possibly use
	ENT.BarricadeTearPositions = {
		Front = {
			Vector(-33,0,0),
			Vector(-33,35,0),
			Vector(-33,-35,0),
		},
		Back = {
			Vector(33,0,0),
			Vector(33,35,0),
			Vector(33,-35,0),
		}
	}
end

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsClear")
	self:NetworkVar("Bool", 1, "CanBeRepaired")
	self:NetworkVar("Int", 0, "PlankCount")
end

local model = Model("models/nzu/barricade/plate.mdl")
function ENT:Initialize()
	if SERVER then
		self:SetModel(model)
		if NZU_NZOMBIES then self:SetNoDraw(true) end -- Don't draw in nZombies
		self:PhysicsInit(SOLID_VPHYSICS)

		self:SetPlankCount(0)
		self.m_iNumBlockingPlanks = 0
		self.m_tPlanks = {}
		

		if not self:GetMaxPlanks() then self:SetMaxPlanks(6) end
		if not self:GetPlankRepairTime() then self:SetPlankRepairTime(1) end
		if not self:GetPlankTearTime() then self:SetPlankTearTime(3) end
		if self:GetTriggerVault() == nil then self:SetTriggerVault(true) end

		for i = 1, self:GetMaxPlanks() do
			timer.Simple(i * 0.1, function()
				if IsValid(self) then self:RepairPlank() end
			end)
		end

		self:SetCanBeRepaired(false)
		self:SetIsClear(self:GetPlankCount() == 0)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end
	end

	self:SetMaterial("models/wireframe")

	-- Determine what positions are available
	if SERVER then --and NZU_NZOMBIES then
		local t = {}

		local ms,mx = Vector(-15,-15,0), Vector(15,15,70)
		for k,v in pairs(self.BarricadeTearPositions) do
			local t2 = {}
			for k2,v2 in pairs(v) do
				local pos = self:LocalToWorld(v2)
				local tr = util.TraceHull({
					start = pos,
					endpos = pos,
					mins = ms,
					maxs = mx,
					filter = self
				})
				if not tr.Hit then
					t2[pos] = NULL
				end
			end
			t[k] = t2
		end
		self.m_tReservedSpots = t
	end
end

if SERVER then
	function ENT:PostEntityPaste(ply, ent, tbl)
		local count = self:GetPlankCount()
		self:SetPlankCount(0)
		for i = 1, count do
			timer.Simple(i * 0.1, function()
				if IsValid(self) then self:RepairPlank() end
			end)
		end
	end

	function ENT:SpawnFunction(ply, tr, class)
		if not tr.Hit then return end
		
		local pos = tr.HitPos
		local ent = ents.Create(class)
		ent:SetPos(pos)
		ent:SetAngles(Angle(0,(ply:GetPos() - tr.HitPos):Angle()[2] + 180,0))
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
			if self:GetPlankCount() >= self:GetMaxPlanks() then return end
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

		--self:SetPlankCount(self:GetPlankCount() + 1)
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
			if not k:GetRepaired() and not k.IsRepairing and not IsValid(k.CurrentUser) then
				table.insert(tbl, k)
			end
		end

		return tbl[math.random(#tbl)]
	end

	function ENT:HasAvailablePlanks()
		for k,v in pairs(self.m_tPlanks) do
			if k:GetRepaired() and not IsValid(k.CurrentUser) then
				return true, k
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
		return Vector(0,0,math.random(40,85)), Angle(0,0,90 + math.random(-40,40))
	end

	function ENT:GetGroundPositionAwayFrom(ply)
		local mult = 1
		if IsValid(ply) and (ply:GetPos() - self:GetPos()):Dot(self:GetAngles():Forward()) > 0 then
			mult = -1
		end

		return self:LocalToWorld(Vector(75*mult, math.random(-10,10), 0))
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

	function ENT:ReserveAvailableTearPosition(z)
		local tbl = (z:GetPos() - self:GetPos()):Dot(self:GetAngles():Forward()) < 0 and self.m_tReservedSpots.Front or self.m_tReservedSpots.Back
		for k,v in pairs(tbl) do
			if not IsValid(v) or v == z then
				tbl[k] = z
				return k
			end
		end
	end

	function ENT:GetVaultPositions()
		return self:LocalToWorld(Vector(35,0,0)), self:LocalToWorld(Vector(-35,0,0))
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
		self:SetPlankCount(self:GetPlankCount() + 1)

		self.m_iNumBlockingPlanks = self.m_iNumBlockingPlanks + 1
		if self:GetIsClear() then
			self:SetIsClear(false)
		end

		if self.m_iNumBlockingPlanks >= self:GetMaxPlanks() then
			self:SetCanBeRepaired(false)
		end
	end

	function ENT:InternalPlankFinishRepair(plank)
		self:StopSound(self.RepairSound)
		self:EmitSound(self.RepairSound)
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
	ENT.VaultHandler = triggervault

	-- Just a simple no-collided MoveToPos
	local function passer(z,self)
		local from,to = self:GetVaultPositions()
		local target = z:GetPos():DistToSqr(from) < z:GetPos():DistToSqr(to) and to or from
		z:SolidMaskDuringEvent(MASK_NPCSOLID_BRUSHONLY)
		z:MoveToPos(target, {lookahead = 10, tolerance = 10, maxage = 3})
		z:CollideWhenPossible()
	end

	function ENT:ZombieInteract(z)
		--debugoverlay.Line(z:GetPos(), self:GetPos(), 20, Color(255,0,0))
		--debugoverlay.Line(z:GetPos(), z:GetPos() + z.loco:GetGroundMotionVector()*20, 20, Color(0,0,255))
		--debugoverlay.Line(z:GetPos(), z:GetCurrentGoal().pos, 20, Color(0,255,0))
		--print(z:GetPathPositionDot(self:GetPos()), (self:GetPos() - z:GetPos()):Dot(z.loco:GetGroundMotionVector()))

		if z:GetMotionDot(self:GetPos()) > 0.25 then -- Stricter moving towards!
			if not self:GetIsClear() then
				z:TriggerEvent("BarricadeTear", self, self.DefaultZombieHandler)
			else
				if self:GetTriggerVault() then
					z:TriggerEvent("BarricadeVault", self, self.VaultHandler)
				else
					z:TriggerEvent("BarricadePass", self, passer)
				end
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
		local result = self:MoveToPos(pos, {lookahead = 20, tolerance = 20, maxage = 3})
		if result == "ok" and not self:ShouldEventTerminate() then
			-- We're in position
			self:FaceTowards(barricade:GetPos())

			while not self:ShouldEventTerminate() and not barricade:GetIsClear() do
				local planktotear = barricade:StartTear(self)

				if IsValid(planktotear) then
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
				else
					self:Timeout(2)
				end
			end

			if not self:ShouldEventTerminate() then
				if barricade.m_tReservedSpots[pos] == self then barricade.m_tReservedSpots[pos] = NULL end
				if self:GetTriggerVault() then
					self:TriggerEvent("BarricadeVault", self, self.VaultHandler)
				else
					self:TriggerEvent("BarricadePass", self, passer)
				end
				return
			end
		else
			self:Timeout(2)
		end
		if barricade.m_tReservedSpots[pos] == self then barricade.m_tReservedSpots[pos] = NULL end
	end
else
	local mat = Material("cable/redlaser")
	local vaultheight = 42
	local col = Color(255,255,255)
	function ENT:Draw()
		self:DrawModel()
		render.SetMaterial(mat)
		render.DrawBeam(
			self:LocalToWorld(Vector(0,-30,vaultheight)),
			self:LocalToWorld(Vector(0,30,vaultheight)),
			10,
			0,
			1,
			col
		)
	end

	function ENT:GetTargetIDText()
		if self:GetCanBeRepaired() then
			return " Repair Barricade ", TARGETID_TYPE_USE
		end
	end
end


--[[-------------------------------------------------------------------------
Planks
---------------------------------------------------------------------------]]


local PLANK = {}
PLANK.Type = "anim"
PLANK.Base = "base_entity"
PLANK.Category = "nZombies Unlimited"
PLANK.PrintName = "Barricade Plank"
PLANK.Author = "Zet0r"

PLANK.Model = Model("models/props_debris/wood_board02a.mdl")

-- Sounds
PLANK.FloatSounds = {Sound("nzu/barricade/float.wav")}
PLANK.SlamSounds = {
	Sound("nzu/barricade/slam_00.wav"),
	Sound("nzu/barricade/slam_01.wav"),
	Sound("nzu/barricade/slam_02.wav"),
	Sound("nzu/barricade/slam_03.wav"),
	Sound("nzu/barricade/slam_04.wav"),
	Sound("nzu/barricade/slam_05.wav"),
}
PLANK.TearSounds = {
	Sound("physics/wood/wood_plank_break1.wav"),
	Sound("physics/wood/wood_plank_break2.wav"),
	Sound("physics/wood/wood_plank_break3.wav"),
	Sound("physics/wood/wood_plank_break4.wav"),
}
local pointssound = Sound("nzu/purchase/accept.wav")

if SERVER then
	AccessorFunc(PLANK, "m_fPlankRipTime", "PlankRipTime", FORCE_NUMBER)
	AccessorFunc(PLANK, "m_fPlankRepairTime", "PlankRepairTime", FORCE_NUMBER)
	AccessorFunc(PLANK, "m_fPlankTearTime", "PlankTearTime", FORCE_NUMBER)
	AccessorFunc(PLANK, "m_eBarricade", "Barricade") -- Entity

	PLANK.DisableDuplicator = true
end



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

			local gpos = bar:GetGroundPositionAwayFrom(ply)
			self:SetPos(gpos)
			self:SetAngles(bar:LocalToWorldAngles(Angle(90,720,math.random(-30,30))))

			local pos,ang = bar:GetPlankPosition(self)

			self.TargetPos = pos
			self.TargetAng = ang
			self.TargetPos_W = bar:LocalToWorld(pos)
			self.TargetAng_W = bar:LocalToWorldAngles(ang)
			self.FloatPos = Vector(gpos.x, gpos.y, self.TargetPos_W.z)
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

			self:EmitSound(self.FloatSounds[math.random(#self.FloatSounds)])
		end
	end

	function PLANK:Tear()
		self:SetParent(nil)
		self:SetRepaired(false)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
		end

		self:EmitSound(self.TearSounds[math.random(#self.TearSounds)])

		hook.Run("nzu_PlankTorn", self, self.CurrentUser)
		self.CurrentUser = nil

		self:GetBarricade():InternalPlankFinishTear(self)
	end

	function PLANK:OnRemove()
		local bar = self:GetBarricade()
		if IsValid(bar) and bar.m_tPlanks[self] then
			bar:SetPlankCount(bar:GetPlankCount() - 1)
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
			self:EmitSound(self.SlamSounds[math.random(#self.SlamSounds)])

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
		local lang = LerpAngle(pct, self.TargetAng_W, ang)

		
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

--[[-------------------------------------------------------------------------
Points!
---------------------------------------------------------------------------]]
if SERVER and NZU_NZOMBIES then
	local maxthisround = 0
	hook.Add("nzu_PlankRepaired", "nzu_Barricade_RepairPoints", function(plank, ply)
		if IsValid(ply) and ply:IsPlayer() then
			if not ply.nzu_RepairedPlanks or ply.nzu_RepairedPlanks < maxthisround then
				ply:GivePoints(10, "BarricadeRepair", plank)
				nzu.PlayClientSound(pointssound, ply)
				ply.nzu_RepairedPlanks = ply.nzu_RepairedPlanks and ply.nzu_RepairedPlanks + 1 or 1
			end
		end
	end)

	hook.Add("nzu_RoundChanged", "nzu_Barricade_RepairPointsMax", function(num)
		maxthisround = math.min(4 + num*5, 49)
		for k,v in pairs(player.GetAll()) do
			v.nzu_RepairedPlanks = nil
		end
	end)
end

if not NZU_SANDBOX then return end
--[[-------------------------------------------------------------------------
Tool!
---------------------------------------------------------------------------]]

local TOOL = {}
TOOL.Category = "Mapping"
TOOL.Name = "#tool.nzu_tool_barricade.name"

TOOL.ClientConVar = {
	["vaults"] = "1",
	["planks"] = "1",
}

function TOOL:LeftClick(trace)
	if SERVER then
		local ply = self:GetOwner()

		local e = ents.Create("nzu_barricade")
		e:SetPos(trace.HitPos)
		e:SetAngles(Angle(0,(ply:GetPos() - trace.HitPos):Angle()[2] + 180,0))
		e:SetTriggerVault(self:GetClientNumber("vaults") ~= 0)
		if self:GetClientNumber("planks") == 0 then e:SetMaxPlanks(0) end
		e:Spawn()
		
		if IsValid(ply) then
			undo.Create("Barricade")
				undo.SetPlayer(ply)
				undo.AddEntity(e)
			undo.Finish()
		end
	end
	return true
end

function TOOL:RightClick(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_barricade" then
		if SERVER then
			local tr = util.TraceLine({
				start = trace.Entity:GetPos(),
				endpos = trace.Entity:GetPos() - Vector(0,0,128),
				filter = trace.Entity
			})
			if tr.Hit then
				trace.Entity:SetPos(tr.HitPos)
				local ang = trace.Entity:GetAngles()
				ang.p = 0
				ang.r = 0
				trace.Entity:SetAngles(ang)
			end
		end
		return true
	end
end

function TOOL:Reload(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_barricade" then
		if SERVER then trace.Entity:Remove() end
		return true
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left"},
		{name = "right"},
		{name = "reload"},
	}

	language.Add("tool.nzu_tool_barricade.name", "Barricade Creator")
	language.Add("tool.nzu_tool_barricade.desc", "Creates a Barricade that zombies has to break through to pass.")

	language.Add("tool.nzu_tool_barricade.left", "Create Barricade")
	language.Add("tool.nzu_tool_barricade.reload", "Remove Barricade")
	language.Add("tool.nzu_tool_barricade.right", "Align with Floor")

	function TOOL.BuildCPanel(panel)
		panel:Help("Spawn a Barricade at the target location. Zombies have to break its planks before they can pass it. Players can never pass them, even without planks.")

		panel:CheckBox("Has Planks", "nzu_tool_barricade_planks")
		panel:CheckBox("Triggers Vaults", "nzu_tool_barricade_vaults")
		panel:Help("Barricades with no planks that trigger Vaults can be used to make vaultable props that players can't pass.")
		panel:Help("When a Zombie is vaulting, it is no-collided to any and all props and entities.")
	end
end

nzu.RegisterTool("barricade", TOOL)