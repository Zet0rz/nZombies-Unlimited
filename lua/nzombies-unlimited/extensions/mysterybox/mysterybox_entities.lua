
print("This is running")
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

ENT.Model = Model("models/nzu/mysterybox/nzu_mystery_box.mdl")
ENT.TeddyModel = Model("models/weapons/w_rif_m4a1.mdl")
ENT.OpenSound = Sound("")
ENT.CloseSound = Sound("")
ENT.JingleSound = Sound("")

function ENT:Initialize()
	if SERVER then
		self:SetModel(self.Model)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetPrice(950)
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsReady")
	self:NetworkVar("Int", 0, "Price")
end

if SERVER then
	function ENT:Use(activator)
		if self:GetIsReady() then
			if IsValid(activator) and activator:IsPlayer() then
				activator:Buy(self:GetPrice(), self.Open, self, activator)
			end
		end
	end

	function ENT:Open(ply)
		if not self:GetIsReady() then return end
		self:SetIsReady(false) -- Cannot be used!

		local seq = self:LookupSequence(self.OpenAnimation)
		self:ResetSequence(seq)
		self:EmitSound(self.OpenSound)

		local class = self:DecideWeapon(ply)
		local wep = ents.Create("nzu_mysterybox_weapon")
		wep:SetParent(self)
		wep:SetLocalPos(Vector(0,0,10))
		wep:SetChosenWeapon(class)
		wep:SetTimeAvailable(20)
		wep:SetMysteryBox(self)
		wep:SetTeddyModel(self.TeddyModel)
		wep:SetOwner(ply)
		wep:Spawn()
		wep:EmitSound(self.JingleSound)
		wep:SetLocalVelocity(Vector(0,0,10))

		self.Weapon = wep
	end

	function ENT:Close()
		if IsValid(self.Weapon) then self.Weapon:Remove() end

		local seq = self:LookupSequence(self.CloseAnimation)
		self:ResetSequence(seq)
		self:EmitSound(self.CloseSound)
		self.ReadyTime = CurTime() + 0.5
	end

	function ENT:OnTeddy(ply)
		if IsValid(ply) then ply:GivePoints(self:GetPrice(), "MysteryBoxRefund") end
		
	end

	function ENT:Think()
		if self.ReadyTime and self.ReadyTime < CurTime() then
			self:SetIsReady(true)
			self.ReadyTime = nil
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

function ENT:Initialize()
	if SERVER then
		self:PhysicsInitBox(Vector(-20,-5,-10), Vector(20,5,10))
		self:SetMoveType(MOVETYPE_NOCLIP)

		self.WindUpTime = CurTime() + 5
		self:RandomizeModel()
		self.NextModel = CurTime() + 1
	end
end

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "WeaponClass")
end

if SERVER then
	AccessorFunc(ENT, "m_iLifetime", "TimeAvailable", FORCE_NUMBER)
	AccessorFunc(ENT, "m_strClass", "ChosenWeapon", FORCE_STRING)
	AccessorFunc(ENT, "m_strTeddyModel", "TeddyModel", FORCE_STRING)
	AccessorFunc(ENT, "m_eBox", "MysteryBox")

	function ENT:Use(activator)
		if (not IsValid(self:GetOwner()) or activator == self:GetOwner()) and self:GetWeaponClass() then
			activator:Give(self:GetWeaponClass())

			if IsValid(self:GetMysteryBox()) then
				self:GetMysteryBox():Close()
			end
			self:Remove()
		end
	end

	local defaultmodels = {
		"models/weapons/w_rif_m4a1.mdl",
	}
	function ENT:RandomizeModel()
		local classes = table.GetKeys(Settings.WeaponList)
		local num = #classes

		local model
		if num > 0 then
			local class = Settings.WeaponList[math.random(num)]
			local wep = weapons.GetStored(class)
			model = wep and (wep.WM or wep.WorldModel)
		end

		self:SetModel(model or defaultmodels[math.random(#defaultmodels)])
	end

	function ENT:Think()
		if self.WindUpTime > CurTime() then
			-- We're winding up
			if self.NextModel < CurTime() then
				self:RandomizeModel()
				self.NextModel = CurTime() + 1
			end
		return end

		if not self.Finalized then
			if not self:GetChosenWeapon() then
				self:SetModel(self:GetTeddyModel())
				self:SetLocalVelocity(Vector(0,0,50))
				self.TeddyFlyTime = CurTime() + 1
			else
				local wep = weapons.GetStored(self:GetChosenWeapon())
				self:SetModel(wep.WM or wep.WorldModel)
				self:SetWeaponClass(self:GetChosenWeapon())
				self.RemoveTime = CurTime() + self:GetTimeAvailable()
				self.FlyDownTime = self.RemoveTime - 10
			end
			self.Finalized = true
		end

		if self.TeddyFlyTime and self.TeddyFlyTime < CurTime() then
			self:Remove()
			if IsValid(self:GetMysteryBox()) then
				self:GetMysteryBox():OnTeddy(self:GetOwner())
			end
		end

		if self.ReturnTime and self.ReturnTime < CurTime() then
			local timeleft = self.RemoveTime - CurTime()
			local dist = -self:GetLocalPos().z

			self:SetLocalVelocity(Vector(0,0,dist/timeleft))

			if self.RemoveTime < CurTime() then
				self:Remove()
				if IsValid(self:GetMysteryBox()) then
					self:GetMysteryBox():Close()
				end
			end
		end
	end
end

scripted_ents.Register(ENT, "nzu_mysterybox")