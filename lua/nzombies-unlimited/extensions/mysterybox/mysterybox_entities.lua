
--[[-------------------------------------------------------------------------
The Fake Box (spawnpoint)
---------------------------------------------------------------------------]]
local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"

-- Also allow spawnmenu spawning
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Mystery Box Spawnpoint"
ENT.Author = "Zet0r"
ENT.Spawnable = true

ENT.Model = Model("models/nzu/mysterybox/nzu_mysterybox_platform.mdl")

if SERVER then
	AccessorFunc(ENT, "m_bPossibleSpawn", "IsPossibleSpawn", FORCE_BOOL)
	if NZU_NZOMBIES then
		AccessorFunc(ENT, "m_eBox", "MysteryBox")

		ENT.BoxPosition = Vector(0,0,10)
		ENT.BoxAngles = Angle(0,0,0)

		function ENT:OnBoxAppear(box)
			self:SetBodygroup(1,1)
		end
		
		function ENT:OnBoxDisappear(box)
			self:SetBodygroup(1,0)
		end
	end
end

function ENT:Initialize()
	if SERVER then
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
end

scripted_ents.Register(ENT, "nzu_mysterybox_spawnpoint")

--[[-------------------------------------------------------------------------
Mystery Box Entity (nZU Only)
---------------------------------------------------------------------------]]
if not NZU_NZOMBIES then return end

local EXT = nzu.Extension()
local Settings = EXT.Settings

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Mystery Box"
ENT.Author = "Zet0r"

ENT.AutomaticFrameAdvance = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.Model = Model("models/nzu/mysterybox/nzu_mystery_box.mdl")
ENT.TeddyModel = Model("models/weapons/w_rif_m4a1.mdl")

ENT.TeddySound = Sound("nzu/mysterybox/child.wav")
ENT.OpenSound = Sound("nzu/mysterybox/open.wav")
ENT.CloseSound = Sound("nzu/mysterybox/close.wav")
ENT.JingleSound = Sound("nzu/mysterybox/music_box.wav")
ENT.DisappearSound = Sound("nzu/mysterybox/disappear.wav")
ENT.AppearSound = Sound("nzu/mysterybox/land_flux.wav")
ENT.PoofSound = Sound("nzu/mysterybox/poof.wav")
ENT.BeamColor = Color(150, 200, 255)

if SERVER then
	-- Only server needs to know sequences
	ENT.OpenAnimation = "box_open"
	ENT.CloseAnimation = "box_close"
	ENT.DisappearAnimation = "box_leave"
	ENT.AppearAnimation = "box_arrive"
end

function ENT:Initialize()
	if SERVER then
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetMoveType(MOVETYPE_NONE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end

		self:SetPrice(950)
		self:SetTimesUsed(0)
	end

	if not self:GetIsReady() then
		self.FirstReady = true
	else
		self:CreateBeam()
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsReady")
	self:NetworkVar("Int", 0, "Price")
	self:NetworkVar("Bool", 1, "IsOpen")
end

if SERVER then
	AccessorFunc(ENT, "m_iTimesUsed", "TimesUsed", FORCE_NUMBER)
	AccessorFunc(ENT, "m_eUser", "CurrentUser")
	AccessorFunc(ENT, "m_eSpawnpoint", "Spawnpoint")

	function ENT:Use(activator)
		if self:GetIsReady() then
			if IsValid(activator) and activator:IsPlayer() then
				activator:Buy(self:GetPrice(), function(ply, box)
					box:Open(ply)
				end, self)
			end
		end
	end

	function ENT:Open(ply)
		if not self:GetIsReady() then return end
		self:SetIsReady(false) -- Cannot be used!
		self:SetCurrentUser(ply)
		self:SetTimesUsed(self:GetTimesUsed() + 1)

		local seq = self:LookupSequence(self.OpenAnimation)
		self:ResetSequence(seq)
		self:EmitSound(self.OpenSound)

		local class = EXT.ShouldGiveTeddy(self, ply) and "" or EXT.DecideWeaponFor(ply)
		local wep = ents.Create("nzu_mysterybox_weapon")
		wep:SetParent(self)
		wep:SetLocalPos(Vector(0,0,0))
		wep:SetLocalAngles(Angle(0,0,0))

		--wep:SetPos(self:GetPos())
		--wep:SetAngles(self:GetAngles())

		wep:SetChosenWeapon(class)
		wep:SetTimeAvailable(20)
		wep:SetMysteryBox(self)
		wep:SetTeddyModel(self.TeddyModel)
		wep:SetTeddySound(self.TeddySound)
		wep:SetPlayer(ply)
		wep:Spawn()
		wep:EmitSound(self.JingleSound)

		self.Weapon = wep

		self:SetIsOpen(true) -- This also triggers CreateOpenEffects on clients
		self:CreateOpenEffect()
	end

	function ENT:Close()
		if IsValid(self.Weapon) then self.Weapon:Remove() end
		self:SetCurrentUser(nil)

		local seq,dur = self:LookupSequence(self.CloseAnimation)
		self:ResetSequence(seq)
		self:EmitSound(self.CloseSound)
		self.ReadyTime = CurTime() + dur

		self:SetIsOpen(false)
		self:RemoveOpenEffect()
	end

	function ENT:OnTeddy(ply)
		if IsValid(ply) then ply:GivePoints(self:GetPrice(), "MysteryBoxRefund") end
	end

	function ENT:Disappear()
		self:SetIsOpen(false)
		local seq,dur = self:LookupSequence(self.DisappearAnimation)
		self:ResetSequence(seq)
		self:EmitSound(self.DisappearSound)

		self.RemoveTime = CurTime() + dur
		self.Weapon = nil -- So it doesn't close us on its own removal

		timer.Simple(3, function() nzu.Announcer("MysteryBox_Laugh") end)
		timer.Simple(5, function() nzu.Announcer("MysteryBox_Leave") end)
		self:OnDisappeared(dur)
	end

	function ENT:Appear(pos, ang)
		if IsValid(pos) then -- It's an entity (spawnpoint!)
			self:SetParent(pos)
			self:SetLocalPos(pos.BoxPosition)
			self:SetLocalAngles(pos.BoxAngles)
			pos:SetMysteryBox(self)
			pos:OnBoxAppear(self)

			self:SetSpawnpoint(pos)
		else
			self:SetPos(pos)
			self:SetAngles(ang)
		end

		self:Spawn()

		local seq,dur = self:LookupSequence(self.AppearAnimation)
		self:ResetSequence(seq)
		self:EmitSound(self.AppearSound)
		self.ReadyTime = CurTime() + dur

		self:OnAppeared(dur)
	end

	function ENT:OnAppeared(dur)
		timer.Simple(dur - 0.2, function()
			if IsValid(self) then self:EmitSound("nzu/mysterybox/land.wav") end
		end)
	end

	function ENT:OnDisappeared(dur)
		local pos = self:GetPos()
		timer.Simple(4.5, function() sound.Play("nzu/mysterybox/whoosh.wav", pos, 100, 100, 1) end)
	end

	function ENT:Think()
		if self.ReadyTime and self.ReadyTime < CurTime() then
			self:SetIsReady(true)
			self.ReadyTime = nil
			if self.FirstReady then
				self:CreateBeam()
				self.FirstReady = nil
			end
		end

		if self.RemoveTime and self.RemoveTime < CurTime() then
			EXT.MoveMysteryBox(self)
		end

		self:NextThink(CurTime())
		return true
	end

	function ENT:OnRemove()
		local point = self:GetSpawnpoint()
		if IsValid(point) and point:GetMysteryBox() == self then
			point:OnBoxDisappear(self)
			point:EmitSound(self.PoofSound)
			point:SetMysteryBox(nil)

			if IsValid(self.Weapon) then self.Weapon:Remove() end
			self:RemoveBeam()
		end
	end

	function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end -- Always be valid on clients
else
	function ENT:Think()
		if self.FirstReady then
			if self:GetIsReady() then
				self:CreateBeam()
				self.FirstReady = nil
			end
		end

		if self:GetIsOpen() ~= self.IsOpen then
			self.IsOpen = self:GetIsOpen()
			if self.IsOpen then
				self:CreateOpenEffect()
			else
				self:RemoveOpenEffect()
			end
		end

		self:NextThink(CurTime())
		return true
	end

	function ENT:Draw()
		self:DrawModel()

		if self:GetIsOpen() then
			self:DrawBoxOpenFill() -- You can override the effect here
		end
	end
	function ENT:DrawTranslucent() end

	ENT.TargetIDTextType = "MysteryBox" -- HUDs can check against this instead, but still default to TARGETID_TYPE_BUY if not implemented
	function ENT:GetTargetIDText()
		if self:GetIsReady() then
			return " random weapon ", TARGETID_TYPE_BUY, self:GetPrice()
		end
	end

	function ENT:OnRemove()
		self:RemoveBeam()
	end

	local m = Material("nzombies-unlimited/particle/light_glow_square")
	local w,h = 92, 26 -- The width and height of the box's light area
	function ENT:DrawBoxOpenFill()
		local x = -h/2
		local y = -w/2
		local h2 = h/2
		for i = 1,5 do
			cam.Start3D2D(self:GetPos() + self:GetUp() * (10 + i), self:GetAngles(), 1)
				surface.SetMaterial(m)
				surface.SetDrawColor(self.BeamColor.r, self.BeamColor.g, self.BeamColor.b, 150)
				--surface.DrawRect(-10,-44,20,88)
				--surface.SetDrawColor(255,255,255)
				surface.DrawTexturedRectUV(x,y, h, h2, 0,0,1,0.5)
				surface.DrawTexturedRectUV(x,y + h2, h, w - h, 0,0.5,1,0.5)
				surface.DrawTexturedRectUV(x,w - w/2 - h2, h, h2, 0,0.5,1,1)
			cam.End3D2D()
		end
	end
end

-- These two functions are shared, as the beam could be initialized by the Server if a subclass chooses to
-- Override these two functions if you want your box to have its own Beam effect
-- Override ENT.BeamColor to just change the color
function ENT:CreateBeam()
	if CLIENT then
		local p = CreateParticleSystem(self, "mysterybox_beam", PATTACH_ABSORIGIN_FOLLOW)
		p:SetControlPoint(2, Vector(self.BeamColor.r/255, self.BeamColor.g/255, self.BeamColor.b/255)) -- Color
		p:SetControlPoint(0, self:GetPos()) -- Bottom position
		p:SetControlPoint(1, self:GetPos() + Vector(0,0,4000)) -- Top position
		self.Beam = p
	end
end

function ENT:RemoveBeam()
	if CLIENT then
		if IsValid(self.Beam) then
			self.Beam:StopEmission(false, true)
			self.Beam = nil
		end
	end
end

function ENT:CreateOpenEffect()
	if CLIENT then
		local p = CreateParticleSystem(self, "mysterybox_roll", PATTACH_ABSORIGIN_FOLLOW)
		p:SetControlPoint(2, Vector(self.BeamColor.r/255, self.BeamColor.g/255, self.BeamColor.b/255)) -- Color
		self.OpenEffect = p
	end
end

function ENT:RemoveOpenEffect()
	if CLIENT then
		if IsValid(self.OpenEffect) then
			self.OpenEffect:StopEmission(false, true)
			self.OpenEffect = nil
		end
	end
end

scripted_ents.Register(ENT, "nzu_mysterybox")

--[[-------------------------------------------------------------------------
Weapon Windup Class
---------------------------------------------------------------------------]]
local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Mystery Box Weapon"
ENT.Author = "Zet0r"

if SERVER then
	ENT.WindupTime = 4.5
	ENT.WindupMovement = Vector(0,0,40)
	ENT.TeddyVelocity = Vector(0,0,50)

	AccessorFunc(ENT, "m_iLifetime", "TimeAvailable", FORCE_NUMBER)
	AccessorFunc(ENT, "m_strClass", "ChosenWeapon", FORCE_STRING)
	AccessorFunc(ENT, "m_strTeddyModel", "TeddyModel", FORCE_STRING)
	AccessorFunc(ENT, "m_strTeddySound", "TeddySound", FORCE_STRING)
	AccessorFunc(ENT, "m_eBox", "MysteryBox")
end

function ENT:Initialize()
	
	if SERVER then
		self:RandomizeModel()
		--self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_OBB)

		self:SetMoveType(MOVETYPE_NOCLIP)
		self:SetCollisionGroup(COLLISION_GROUP_NONE)
		self:SetUseType(SIMPLE_USE)

		self.WindingTime = CurTime() + self.WindupTime
		self:SetLocalVelocity(self.WindupMovement/self.WindupTime)

		self.NextModel = CurTime() + 0.5/(self.WindingTime - CurTime())
		self:SetWeaponClass("")
	end
	self:DrawShadow(false)
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "WeaponClass")
	self:NetworkVar("Entity", 0, "Player")
end

if SERVER then
	function ENT:Use(activator)
		if (not IsValid(self:GetPlayer()) or activator == self:GetPlayer()) and self:GetWeaponClass() ~= "" then
			activator:Give(self:GetWeaponClass())
			self:Remove()
		end
	end

	local defaultmodels = {
		"models/weapons/w_rif_m4a1.mdl",
		"models/weapons/w_rif_ak47.mdl",
	}
	function ENT:RandomizeModel(model)
		local models = EXT.GetModelsList()
		local num = #models

		local model
		if num > 0 then
			model = models[math.random(num)]
		end

		self:SetModel(model or defaultmodels[math.random(#defaultmodels)])
		self:RotateToModel()
	end

	function ENT:RotateToModel()
		local a,b = self:GetModelBounds()
		if b.x - a.x > b.y - a.y then
			self:SetLocalAngles(Angle(0,90,0))
		else
			self:SetLocalAngles(Angle(0,0,0))
		end
	end

	function ENT:Think()
		if self.WindingTime > CurTime() then
			-- We're winding up
			if self.NextModel < CurTime() then
				self:RandomizeModel()
				self.NextModel = CurTime() + 0.5/(self.WindingTime - CurTime())
			end
		return end

		if not self.Finalized then
			if not self:GetChosenWeapon() or self:GetChosenWeapon() == "" then
				self:SetModel(self:GetTeddyModel())
				self:RotateToModel()
				self.TeddyFlyTime = CurTime() + 2
				self.RemoveTime = CurTime() + 5
				
				if IsValid(self:GetMysteryBox()) then
					self:GetMysteryBox():OnTeddy(self:GetPlayer(), self)
				end
				nzu.PlayClientSound(self:GetTeddySound())
			else
				local wep = weapons.GetStored(self:GetChosenWeapon())
				if wep then
					self:SetModel(wep.WM or wep.WorldModel)
				else
					self:SetModel(defaultmodels[1])
				end
				self:SetWeaponClass(self:GetChosenWeapon())
				self:RotateToModel()

				self.RemoveTime = CurTime() + self:GetTimeAvailable()
				self.FlyDownTime = self.RemoveTime - 10
			end
			self:SetLocalVelocity(Vector(0,0,0))
			self.Finalized = true
		end

		if self.TeddyFlyTime and self.TeddyFlyTime < CurTime() then
			self:SetLocalVelocity(self.TeddyVelocity)

			if self.RemoveTime < CurTime() then
				if IsValid(self:GetMysteryBox()) then
					self:GetMysteryBox():Disappear()
				end
				self:Remove()
			end
		elseif self.ReturnTime and self.ReturnTime < CurTime() then
			local timeleft = self.RemoveTime - CurTime()

			self:SetLocalVelocity(self.WindupMovement/timeleft)

			if self.RemoveTime < CurTime() then
				self:Remove()
				if IsValid(self:GetMysteryBox()) then
					self:GetMysteryBox():Close()
				end
			end
		end
	end

	function ENT:OnRemove()
		if IsValid(self:GetMysteryBox()) and self:GetMysteryBox().Weapon == self then
			self:GetMysteryBox():Close()
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
	function ENT:DrawTranslucent() end

	function ENT:GetTargetIDText()
		if self.SavedClass ~= self:GetWeaponClass() then
			if self:GetWeaponClass() ~= "" then
				local wep = weapons.GetStored(self:GetWeaponClass())
				if wep then
					self.WeaponName = " "..wep.PrintName.." "
				else
					self.WeaponName = " UNKNOWN WEAPON "
				end
			else
				self.WeaponName = nil
			end
			self.SavedClass = self:GetWeaponClass()
		end

		if self.WeaponName and (not IsValid(self:GetPlayer()) or self:GetPlayer() == LocalPlayer()) then
			return " pick up "..self.WeaponName, TARGETID_TYPE_USE, self
		end
	end
end

scripted_ents.Register(ENT, "nzu_mysterybox_weapon")