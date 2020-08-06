ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Mystery Box"
ENT.Author = "Zet0r"

ENT.AutomaticFrameAdvance = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

-- You can override these in a subclass entity (with a different model for example)
ENT.BeamColor = Color(150, 200, 255)

if SERVER then
	-- Only server needs to know sequences, models and sounds
	ENT.Model = Model("models/nzu/mysterybox/nzu_mystery_box.mdl")
	ENT.OpenAnimation = "box_open"
	ENT.CloseAnimation = "box_close"
	ENT.DisappearAnimation = "box_leave"
	ENT.AppearAnimation = "box_arrive"

	ENT.TeddyModel = Model("models/weapons/w_rif_m4a1.mdl")
	ENT.TeddySound = Sound("nzu/mysterybox/child.wav")

	ENT.OpenSound = Sound("nzu/mysterybox/open.wav")
	ENT.CloseSound = Sound("nzu/mysterybox/close.wav")
	ENT.JingleSound = Sound("nzu/mysterybox/music_box.wav")
	ENT.DisappearSound = Sound("nzu/mysterybox/disappear.wav")
	ENT.AppearSound = Sound("nzu/mysterybox/land_flux.wav")
	ENT.PoofSound = Sound("nzu/mysterybox/poof.wav")
	ENT.WhooshSound = Sound("nzu/mysterybox/whoosh.wav")
	ENT.LandSound = Sound("nzu/mysterybox/land.wav")
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
		if self:GetIsReady() and IsValid(activator) and activator:IsPlayer() then
			activator:Buy(self:GetPrice(), function(ply, box)
				box:Open(ply)
			end, self)
		end
	end

	function ENT:ShouldGiveTeddy(ply)
		local b = hook.Run("nzu_MysteryBox_OverrideTeddy", self, ply)
		if b == nil then
			local r = math.random()
			local t = box:GetTimesUsed()
			local ch = t > 12 and 0.5 or t > 8 and 0.3 or 0.15 -- 50% over 12 uses, 30% 8-12 uses, 15% under 8 uses

			b = r < ch
		end

		return b
	end

	function ENT:ReserveSpawnpoint(p)
		local target
		if p then
			if IsValid(p) and (not IsValid(p.ReservedBox) or p.ReservedBox == self) then
				target = p
			end
		else
			target = nzu.GetRandomAvailableMysteryBoxSpawnpoint()
		end

		if target then
			-- Unreserve the previously reserved one, if any
			if IsValid(self.ReservedSpawnpoint) and self.ReservedSpawnpoint.ReservedBox == self then
				self.ReservedSpawnpoint.ReservedBox = nil
			end

			target.ReservedBox = self -- Reserve this point for this box to move to
			self.ReservedSpawnpoint = target
			return true
		end
		return false
	end

	function ENT:Open(ply)
		if not self:GetIsReady() then return end
		self:SetIsReady(false) -- Cannot be used!
		self:SetCurrentUser(ply)
		self:SetTimesUsed(self:GetTimesUsed() + 1)

		local seq = self:LookupSequence(self.OpenAnimation)
		self:ResetSequence(seq)
		self:EmitSound(self.OpenSound)

		local wep = ents.Create("nzu_mysterybox_weapon")
		wep:SetParent(self)
		wep:SetLocalPos(Vector(0,0,0))
		wep:SetLocalAngles(Angle(0,0,0))

		-- We set model pool so the entity doesn't have to go through all weapons to get the models
		-- This also makes it so it still has these models, even if it's going to be a teddy in which the windup doesn't actually need a weapon pool
		wep:SetModelPool(nzu.GetMysteryBoxModelPool())
		wep:SetPlayer(ply)
		wep.MysteryBox = self

		if self:ShouldGiveTeddy(ply) and self:ReserveSpawnpoint() then
			wep:SetChosenWeapon("") -- Nothing, we do our own overrides here
			wep.FinishWindup = self.TeddyFinishWindup -- We override the FinishWindup function to do our own thing instead!
			wep.nzu_RefundCost = self:GetPrice()
		else
			wep:SetWeaponPool(nzu.GetMysteryBoxWeaponPoolFor(ply)) -- Set the weapons it can get it for
			wep:SetTimeAvailable(20)
		end

		-- Make it so that when it is removed, we close ourselves
		wep.OnRemove = function()
			if self:GetIsOpen() then
				self:Close()
			end
			self.Weapon = nil
		end

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

	-- This function's a bit funny. It is actually never called on the box. Instead, it is given to the Windup entity
	-- That means that the "self" inside this function is actually the windup, not the box!
	function ENT:TeddyFinishWindup()
		if IsValid(self:GetPlayer()) then
			self:GetPlayer():GivePoints(self.nzu_RefundCost, "MysteryBoxRefund")
		end

		self:EmitSound(self.MysteryBox.TeddySound)
		self:SetModel(self.MysteryBox.TeddyModel)

		self.ReturnTime = CurTime() + 2
		self.RemoveTime = CurTime() + 5
		self:SetWindupVelocity(Vector(0,0,-35)) -- This makes it so that it thinks "returning" means flying up by this distance

		self.OnRemove = function(s)
			self.MysteryBox:Disappear() -- Instead of close, and whether or not it is open
			self.MysteryBox.Weapon = nil
		end
	end

	-- Back to the box being self
	function ENT:Disappear()
		self:SetIsOpen(false)
		local seq,dur = self:LookupSequence(self.DisappearAnimation)
		self:ResetSequence(seq)
		self:EmitSound(self.DisappearSound)

		self.MoveTime = CurTime() + dur
		self.Weapon = nil -- So it doesn't close us on its own removal

		timer.Simple(3, function() nzu.Announcer("mysterybox/leave") end)
		self:OnDisappear(dur)
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

	-- When it first appears. Dur is the duration of the appear animation
	function ENT:OnAppear(dur)
		timer.Simple(dur - 0.2, function()
			if IsValid(self) then self:EmitSound(self.LandSound) end
		end)
	end
	function ENT:OnAppeared() end -- When it has fully appeared

	-- When it first disappears. Dur is the duration of the disappear animation
	function ENT:OnDisappear(dur) end
	function ENT:OnDisappeared() -- When it has fully disappeared
		sound.Play(self.WhooshSound, self:GetPos(), 100, 100, 1)
	end

	function ENT:Move(newpoint)
		local target = newpoint

		-- If the box was set to move to some specific point, given through the Teddy roll logic
		if self.ReservedSpawnpoint then
			if not IsValid(target) then -- Only if "newpoint" wasn't forced though
				target = self.ReservedSpawnpoint -- Chosen point will be the reserved one
			else
				self.ReservedSpawnpoint = nil -- Remove our own reserved spawnpoint
			end
			self.ReservedSpawnpoint.ReservedBox = nil -- Always unreserve the point itself, as it should not be reserved neither if we are now on it, or if we moved to another
		end

		if not IsValid(target) then
			target = nzu.GetRandomAvailableMysteryBoxSpawnpoint()
			if not IsValid(target) then
				self:Remove()
				return
			end
		end

		self:SetTimesUsed(0)
		self:SetIsReady(false)
		self:RemoveBeam()

		local point = self:GetSpawnpoint()
		if IsValid(point) and point:GetMysteryBox() == self then
			point:OnBoxDisappear(self)
			point:EmitSound(self.PoofSound)
			point:SetMysteryBox(nil)

			if IsValid(self.Weapon) then
				self.Weapon.OnRemove = nil -- Do nothing on this removal
				self.Weapon:Remove()
			end
		end

		self:OnDisappeared()

		self.FirstReady = true
		self:Appear(target)
	end

	function ENT:Think()
		if self.ReadyTime and self.ReadyTime < CurTime() then
			self:SetIsReady(true)
			self.ReadyTime = nil
			if self.FirstReady then
				self:CreateBeam()
				self.FirstReady = nil

				self:OnAppeared()
			end
		end

		if self.MoveTime and self.MoveTime < CurTime() then
			self:Move()
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
		if self.FirstReady and self:GetIsReady() then
			self:CreateBeam()
			self.FirstReady = nil
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
	
	function ENT:GetTargetIDText()
		if self:GetIsReady() then
			return "Buy", "Random Weapon",  self:GetPrice()
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