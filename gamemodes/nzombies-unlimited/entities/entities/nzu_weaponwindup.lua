AddCSLuaFile()

--[[-------------------------------------------------------------------------
Weapon Windup Class
This class can be used to create a weapon that cycles through a list of possible options
landing on a random one after a set time. It can also have a specific one "hiddenly" chosen
---------------------------------------------------------------------------]]
ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Mystery Weapon"
ENT.Author = "Zet0r"

if SERVER then
	AccessorFunc(ENT, "m_iWindupTime", "WindupTime", FORCE_NUMBER) -- The amount of time it will take to wind up to the chosen weapon
	AccessorFunc(ENT, "m_vWindupVelocity", "WindupVelocity") -- The speed of the windup as it is in the middle of winding up
	AccessorFunc(ENT, "m_iLifetime", "TimeAvailable", FORCE_NUMBER) -- How long it remains available to be picked up. Don't set/set to nil to remain infinitely.
	AccessorFunc(ENT, "m_tWeaponPool", "WeaponPool") -- The table of possible weapons. Can be both weighted list, or normal sequential array. Is used for models.
	AccessorFunc(ENT, "m_strClass", "ChosenWeapon", FORCE_STRING) -- What weapon class is chosen in the end. Don't set/set to nil to make random from above pool.
	AccessorFunc(ENT, "m_tModelPool", "ModelPool") -- The table of winding models. If this isn't set before spawn, it will get all models from its pool of weapons.
	AccessorFunc(ENT, "m_iReturnDelay", "ReturnDelay", FORCE_NUMBER) -- How long until it starts returning. It will return to the position it was spawned in over the remaining lifetime.
	-- Do not set/Set to nil to make it remain out where it landed with its WindupVelocity. Only works if WindupVelocity and TimeAvailable is set.
end

function ENT:Initialize()
	if SERVER then
		--self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_OBB)

		self:SetMoveType(MOVETYPE_NOCLIP)
		self:SetCollisionGroup(COLLISION_GROUP_NONE)
		self:SetUseType(SIMPLE_USE)

		if not self:GetChosenWeapon() then
			self:SetChosenWeapon(nzu.SelectWeapon(self:GetWeaponPool(), self:GetPlayer()))
		end

		local time = self:GetWindupTime()
		if time and time > 0 then
			self:StartWindup(time)
		else
			self:FinishWindup()
		end
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
			self:OnPickedUp(activator)
		end
	end

	local defaultmodels = {
		"models/weapons/w_rif_m4a1.mdl",
		"models/weapons/w_rif_ak47.mdl",
	}
	function ENT:RandomizeModel(model)
		local models = self:GetModelPool()
		local num = #models

		local model
		if num > 0 then
			local ran = math.random(num)
			model = models[ran]
			if model == self:GetModel() then
				model = models[ran < num and ran + 1 or 1]
			end
		end

		self:SetModel(model or defaultmodels[math.random(#defaultmodels)])
		self:RotateToModel()
	end

	-- Rotates the model so that the widest side points forward
	function ENT:RotateToModel()
		local a,b = self:GetModelBounds()
		if b.x - a.x > b.y - a.y then
			self:SetLocalAngles(Angle(0,90,0))
		else
			self:SetLocalAngles(Angle(0,0,0))
		end
	end

	function ENT:StartWindup(time)
		if not self:GetModelPool() then
			local t = {}
			local weps = self:GetWeaponPool()
			if weps then
				if weps[1] then
					for k,v in pairs(weps) do
						local wep = weapons.GetStored(v)
						if wep then
							local model = wep.WM or wep.WorldModel
							if model and model ~= "" then
								table.insert(t, model)
							end
						end
					end
				else
					for k,v in pairs(weps) do
						local wep = weapons.GetStored(k)
						if wep then
							local model = wep.WM or wep.WorldModel
							if model and model ~= "" then
								table.insert(t, model)
							end
						end
					end
				end
			end

			self:SetModelPool(t)
		end

		self:RandomizeModel()
		self.WindingTime = CurTime() + (time or self:GetWindupTime())
		if self:GetWindupVelocity() then
			self:SetLocalVelocity(self:GetWindupVelocity())
		end

		self.NextModel = CurTime() + 0.5/(self.WindingTime - CurTime())
		self:SetWeaponClass("") -- We aren't ready to be picked up, and we don't show what the final weapon is!
	end

	function ENT:FinishWindup()
		local wep = weapons.GetStored(self:GetChosenWeapon())
		if wep then
			self:SetModel(wep.WM or wep.WorldModel)
		else
			self:SetModel(defaultmodels[1])
		end
		self:RotateToModel()
		self:SetLocalVelocity(Vector(0,0,0))

		-- This marks it being ready for pickup
		self:SetWeaponClass(self:GetChosenWeapon())
		if self:GetTimeAvailable() then
			self.RemoveTime = CurTime() + self:GetTimeAvailable()
			if self:GetReturnDelay() then
				self.ReturnTime = CurTime() + self:GetReturnDelay()
			end
		end
		
		self.Finalized = true

		if self.OnFinishedWindup then self:OnFinishedWindup() end -- Let's provide accessibility for other code to add callbacks :)
	end

	-- Can be overwritten
	function ENT:OnPickedUp(ply)
		ply:Give(self:GetWeaponClass())
		self:Remove()
	end

	function ENT:Think()
		if self.WindingTime and self.WindingTime > CurTime() then
			-- We're winding up
			--if self.NextModel < CurTime() then
				self:RandomizeModel()
				--self.NextModel = CurTime() + 0.5/(self.WindingTime - CurTime())
				self:NextThink(CurTime() + 0.30/(self.WindingTime - CurTime()))
			--end
		return true end

		if not self.Finalized then
			self:FinishWindup()
		end

		if self.ReturnTime and self.ReturnTime < CurTime() then
			local timeleft = self.RemoveTime - CurTime() -- Time until expiration
			local dist = -self:GetWindupVelocity() * self:GetWindupTime() -- Distance it travelled during its windup time (assuming it hasn't changed)

			self:SetLocalVelocity(dist/timeleft)
			self.ReturnTime = nil -- We don't need to do this again
		end

		if self.RemoveTime and self.RemoveTime < CurTime() then
			if self.OnExpired then self:OnExpired() end -- Callback :D
			self:Remove()
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
	--function ENT:DrawTranslucent() end
	ENT.DrawTranslucent = ENT.Draw

	function ENT:GetTargetIDText()
		if self.SavedClass ~= self:GetWeaponClass() then
			if self:GetWeaponClass() ~= "" then
				local wep = weapons.GetStored(self:GetWeaponClass())
				if wep then
					self.WeaponName = wep.PrintName
				else
					self.WeaponName = "???"
				end
			else
				self.WeaponName = nil
			end
			self.SavedClass = self:GetWeaponClass()
		end

		if self.WeaponName and (not IsValid(self:GetPlayer()) or self:GetPlayer() == LocalPlayer()) then
			return "Weapon", self.WeaponName, self.SavedClass
		end
	end
end