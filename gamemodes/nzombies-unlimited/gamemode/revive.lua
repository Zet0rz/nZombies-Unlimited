local PLAYER = FindMetaTable("Player")
local ENTITY = FindMetaTable("Entity")
nzu.AddPlayerNetworkVar("Bool", "IsDowned") -- So prediction can work with it too


--[[-------------------------------------------------------------------------
Basic Revive state
---------------------------------------------------------------------------]]
if SERVER then
	util.AddNetworkString("nzu_playerdowned") -- Server: Broadcast that a player was downed

	-- We can change this later when we want variable bleedout time
	function PLAYER:GetBleedoutTime()
		return 45 -- Seconds
	end

	local function networkdowned(ply, time, death)
		net.Start("nzu_playerdowned")
			net.WriteEntity(ply)
			net.WriteBool(true)
			net.WriteFloat(time)
			net.WriteFloat(death)
		net.Broadcast()
	end

	function PLAYER:DownPlayer()
		if not self:GetIsDowned() then
			self:SetHealth(1) -- Is this a nice touch or nah?
			self:SetIsDowned(true)
			self.nzu_DownedTime = CurTime()
			self.nzu_BleedoutTime = CurTime() + self:GetBleedoutTime()

			networkdowned(self, self.nzu_DownedTime, self.nzu_BleedoutTime)

			hook.Run("nzu_PlayerDowned", self)

			self:AddUntargetability("Downed")
		end
	end

	function PLAYER:SetBleedoutTime(time)
		self.nzu_BleedoutTime = time
		networkdowned(self, self.nzu_DownedTime, self.nzu_BleedoutTime)

		hook.Run("nzu_PlayerBleedoutChanged", self)
	end

	-- Promised Revive: A downed player is promised to be revived - therefore, do not count them as out
	function PLAYER:SetPromisedRevive(t)
		self.nzu_PromisedRevive = t
		hook.Run("nzu_PlayerPromisedRevive", self, t)
	end
	function PLAYER:GetPromisedRevive() return self.nzu_PromisedRevive end
	function PLAYER:GetCountsDowned() return self:GetIsDowned() and not self:GetPromisedRevive() end -- Downed and not promised to be revived

	function PLAYER:RevivePlayer(savior)
		if self:GetIsDowned() then
			self:SetHealth(100)
			self:SetIsDowned(false)
			self.nzu_DownedTime = nil
			self.nzu_BleedoutTime = nil
			self.nzu_PromisedRevive = nil

			net.Start("nzu_playerdowned")
				net.WriteEntity(self)
				net.WriteBool(false)
				net.WriteBool(true)
				if IsValid(savior) then
					net.WriteBool(true)
					net.WriteEntity(savior)
				else
					net.WriteBool(false)
				end
			net.Broadcast()

			hook.Run("nzu_PlayerRevived", self, savior)

			self:RemoveUntargetability("Downed")
		end
	end

	function ENTITY:CanBeRevived()
		return self.nzu_CanBeRevived
	end

	function PLAYER:CanBeRevived()
		return true
	end

	hook.Add("nzu_PlayerGivePoints", "nzu_Revive_DownedPlayersNoPoints", function(ply, tbl)
		if ply:GetIsDowned() then tbl.Points = 0 return end -- DO NOT return normally! We only return because we set to 0 anyway, no other modifiers can do anything!
	end)
end

if CLIENT then
	net.Receive("nzu_playerdowned", function()
		local ply = net.ReadEntity()
		if net.ReadBool() then
			local already = ply.nzu_DownedTime

			ply.nzu_DownedTime = net.ReadFloat()
			ply.nzu_BleedoutTime = net.ReadFloat()

			hook.Run(already and "nzu_PlayerBleedoutChanged" or "nzu_PlayerDowned", ply)
		else
			ply.nzu_DownedTime = nil
			ply.nzu_BleedoutTime = nil
			if net.ReadBool() then
				local savior
				if net.ReadBool() then savior = net.ReadEntity() end
				hook.Run("nzu_PlayerRevived", ply, savior)
			else
				hook.Run("nzu_PlayerBledOut", ply)
			end
		end
	end)
end

-- Utility
function nzu.GetDownedPlayers()
	local tbl = {}
	for k,v in pairs(player.GetAll()) do
		if v:GetIsDowned() then table.insert(tbl, v) end
	end
	return tbl
end

function nzu.GetNotDownedPlayers()
	local tbl = {}
	for k,v in pairs(player.GetAll()) do
		if not v:GetIsDowned() then table.insert(tbl, v) end
	end
	return tbl
end







--[[-------------------------------------------------------------------------
Death & Suicide Handling
---------------------------------------------------------------------------]]
if SERVER then

	-- Overwrite PLAYER:Kill() to down first, then kill
	local dokill = PLAYER.Kill
	function PLAYER:Kill()
		if not self:GetIsDowned() then
			self:DownPlayer()
		else
			dokill(self)
		end
	end

	-- Handle bleedout in a player's Post Think
	hook.Add("PlayerPostThink", "nzu_Revive_Bleedout", function(ply)
		if ply:GetIsDowned() then
			if ply.nzu_BleedoutTime < CurTime() then
				ply:Kill() -- Just using Kill() is how to kill a downed player
			end
		end
	end)

	-- Clear revive status on finally dying (such as bleeding out)
	hook.Add("PostPlayerDeath", "nzu_Revive_PlayerDeathCleanup", function(ply)
		if ply:GetIsDowned() then
			ply:SetIsDowned(false)
			ply.nzu_DownedTime = nil
			ply.nzu_BleedoutTime = nil

			net.Start("nzu_playerdowned")
				net.WriteEntity(ply)
				net.WriteBool(false)
				net.WriteBool(false)
			net.Broadcast()
			hook.Run("nzu_PlayerBledOut", ply)
		end
	end)

	hook.Add("CanPlayerSuicide", "nzu_Revive_PlayerSuicice", function(ply)
		-- Not downed players go down when they suicide
		if not ply:GetIsDowned() then
			ply:DownPlayer()
			return false
		end

		-- Already downed players can die like normal
		return true
	end)
end







--[[-------------------------------------------------------------------------
Revive Handling
---------------------------------------------------------------------------]]
function PLAYER:GetReviveTime()
	return 4 -- Change this to hook later? Or some system to change player revive times (for perks, powerups, etc)
end

if SERVER then
	util.AddNetworkString("nzu_playerreviving") -- Server: Notify clients that a player is being revived by another

	function PLAYER:StartReviving(target, time2)
		if self.nzu_ReviveLocked then return end

		local time = time2 or self:GetReviveTime()
		if time > 0 then
			self.nzu_ReviveTime = CurTime() + time
			self.nzu_ReviveTarget = target
			self.nzu_ReviveStartTime = CurTime()
			hook.Run("nzu_PlayerStartedRevive", self, target, time)

			local w = self:GetWeaponInSlot("Syringe")
			if IsValid(w) then
				w:DeployAnimation() -- If we have a weapon in Syringe slot, this is deployed. It may modify the ReviveTime!
			else
				self:Give("nzu_revive_syringe") -- If not, give default syringe weapon (which is only temporarily held)
			end

			net.Start("nzu_playerreviving")
				net.WriteEntity(self)
				net.WriteBool(true)
				net.WriteFloat(self.nzu_ReviveTime)
				net.WriteEntity(target)
			net.Broadcast()
		else
			target:RevivePlayer(self)
		end
	end

	function PLAYER:StopReviving()
		if self.nzu_ReviveLocked then return end

		local target = self.nzu_ReviveTarget
		self.nzu_ReviveTime = nil
		self.nzu_ReviveTarget = nil
		self.nzu_ReviveStartTime = nil

		net.Start("nzu_playerreviving")
			net.WriteEntity(self)
			net.WriteBool(false)
		net.Broadcast()

		hook.Run("nzu_PlayerStoppedRevive", self, target)
	end

	function PLAYER:StartForcedReviving(target, time)
		self.nzu_ReviveLocked = false
		self:StartReviving(target, time)
		self.nzu_ReviveLocked = true
	end

	function PLAYER:StopForcedReviving()
		self.nzu_ReviveLocked = nil
		self:StopReviving()
	end

	-- Find players for use
	local reviverange = 100
	local quicktrace = util.QuickTrace
	hook.Add("FindUseEntity", "nzu_Revive_UsePlayers", function(ply, ent)
		-- Optimization. We already block downed players from using below, but we may as well save the trace too
		if not ply.nzu_ReviveLocked then
			if not ply:GetIsDowned() then
				local tr = quicktrace(ply:EyePos(), ply:GetAimVector() * reviverange, ply)
				local target = tr.Entity

				if IsValid(target) and target:CanBeRevived() and target:GetIsDowned() then
					return target
				end
			end
			if ply.nzu_ReviveTarget then
				ply:StopReviving()
			end
		end
	end)

	-- Downed players can't use anything
	hook.Add("nzu_PlayerStartUse", "nzu_Revive_RevivePlayers", function(ply, ent)
		if not ply.nzu_ReviveLocked then
			if IsValid(ent) and ent:CanBeRevived() and ent:GetIsDowned() then
				if ply.nzu_ReviveTarget ~= ent then
					ply:StartReviving(ent)
				end
			elseif ply.nzu_ReviveTarget then
				ply:StopReviving()
			end
		end
	end)

	hook.Add("nzu_PlayerStopUse", "nzu_Revive_StopReviving", function(ply, ent)
		if not ply.nzu_ReviveLocked and ent == ply.nzu_ReviveTarget then
			ply:StopReviving()
		end
	end)

	-- Keep an eye on players' revive times
	hook.Add("PlayerPostThink", "nzu_Revive_Reviving", function(ply)
		if ply.nzu_ReviveTime and ply.nzu_ReviveTime <= CurTime() then
			if IsValid(ply.nzu_ReviveTarget) then ply.nzu_ReviveTarget:RevivePlayer(ply) end

			ply:StopForcedReviving() -- Completing a revive also stops a forced one
		end
	end)
end

if CLIENT then
	net.Receive("nzu_playerreviving", function()
		local ply = net.ReadEntity()
		if net.ReadBool() then
			ply.nzu_ReviveTime = net.ReadFloat()
			ply.nzu_ReviveTarget = net.ReadEntity()
			ply.nzu_ReviveStartTime = CurTime()

			if ply == LocalPlayer() then
				local w = ply:GetWeaponInSlot("Syringe")
				if IsValid(w) then
					w:DeployAnimation() -- If we have a weapon in Syringe slot, we perform the same action as Server. This may happen delayed (given the net message), so it can never truly be predicted
				end
			end

			hook.Run("nzu_PlayerStartedRevive", ply, ply.nzu_ReviveTarget, ply.nzu_ReviveTime - CurTime())
		else
			local target = ply.nzu_ReviveTarget

			ply.nzu_ReviveTime = nil
			ply.nzu_ReviveTarget = nil
			ply.nzu_ReviveStartTime = nil
			hook.Run("nzu_PlayerStoppedRevive", ply, target)
		end
	end)
end






--[[-------------------------------------------------------------------------
Movement & Aiming for Downed Players
---------------------------------------------------------------------------]]
local visionlowered = Vector(0,0,-40)
local crawlspeed = 30

hook.Add("SetupMove", "nzu_Revive_DownedMovement", function(ply, mv, cmd)
	if ply:GetIsDowned() then
		mv:SetMaxClientSpeed(crawlspeed)
		mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP + IN_DUCK))) -- Remove jump and crouch keys
	end
end)

-- Overwrite shooting pos to adjust to lower view
local oldshoot = PLAYER.GetShootPos
function PLAYER:GetShootPos()
	local old = oldshoot(self)
	if self:GetIsDowned() then
		return old + visionlowered
	else
		return old
	end
end

local oldeyes = ENTITY.EyePos
function PLAYER:EyePos()
	local old = oldeyes(self)
	if self:GetIsDowned() then
		return old + visionlowered
	else
		return old
	end
end

if CLIENT then
	-- CalcViews
	local rotang = Angle(0,0,20)
	hook.Add("CalcView", "nzu_Revive_DownedView", function(pl, pos, ang, fov, znear, zfar)
		local ply = pl:GetObserverTarget()
		if not IsValid(ply) then ply = pl end
		if ply:GetIsDowned() then
			local view = {fov = fov, znear = znear, zfar = zfar}
			view.origin = pos + visionlowered
			view.angles = ang + rotang

			return view
		end
	end)

	hook.Add("CalcViewModelView", "nzu_Revive_DownedViewmodel", function(wep, vm, oldp, olda, pos, ang)
		local ply = LocalPlayer():GetObserverTarget()
		if not IsValid(ply) then ply = LocalPlayer() end
		if ply:GetIsDowned() then
			return pos + visionlowered, ang + rotang
		end
	end)
end







--[[-------------------------------------------------------------------------
Animations for downed players
---------------------------------------------------------------------------]]
hook.Add("CalcMainActivity", "nzu_Revive_DownedAnimation", function(ply, vel)
	if ply:GetIsDowned() then

		if vel:Length2D() > 1 then
			ply.CalcIdeal = ACT_HL2MP_SWIM_REVOLVER
		else
			ply.CalcIdeal = ACT_HL2MP_SWIM_PISTOL
		end
		--ply.CalcIdeal = ACT_DOD_CROUCH_ZOOMED
		--[[local num = math.Round(CurTime()*1)% 30 + 1960
		print(num)
		ply.CalcIdeal = 1989]]

		return ply.CalcIdeal, ply.CalcSeqOverride
	end
end)

local cyclex, cycley = 0.6,0.65
local hullchange = Vector(0,0,25)

local loweredpos = Vector(0,0,-30)
local rotate = Angle(0,0,-30)
hook.Add("UpdateAnimation", "nzu_Revive_DownedAnimation", function(ply, vel, seqspeed)
	if ply:GetIsDowned() then
		local movement = 0

		local len = vel:Length2D()
		if len > 1 then
			movement = len / seqspeed
		else
			local cycle = ply:GetCycle()
			if cycle < cyclex or cycle > cycley then
				movement = 5
			end
		end

		ply:SetPoseParameter("move_x", -1)
		ply:SetPlaybackRate(movement)

		if not ply.nzu_DownedAnim then
			ply:ManipulateBonePosition(0, loweredpos)
			ply:ManipulateBoneAngles(0, rotate)
			ply.nzu_DownedAnim = true
		end

		return true
	elseif ply.nzu_DownedAnim then
		ply:ManipulateBonePosition(0, Vector(0,0,0))
		ply:ManipulateBoneAngles(0, Angle(0,0,0))
		ply.nzu_DownedAnim = false
	end
end)



--[[-------------------------------------------------------------------------
Clientside HUD Drawing
---------------------------------------------------------------------------]]
if CLIENT then
	local downedplayers = {}
	hook.Add("nzu_PlayerDowned", "nzu_Revive_HUDDownedIndicator", function(ply)
		downedplayers[ply] = NULL
	end)

	local function playernolongerdown(ply)
		downedplayers[ply] = nil
	end
	hook.Add("nzu_PlayerRevived", "nzu_Revive_HUDDownedIndicator", playernolongerdown)
	hook.Add("nzu_PlayerBledOut", "nzu_Revive_HUDDownedIndicator", playernolongerdown)
	hook.Add("EntityRemoved", "nzu_Revive_HUDDownedIndicator", playernolongerdown)

	-- When players start reviving a target, check to see if they're faster and update the revivor if so
	hook.Add("nzu_PlayerStartedRevive", "nzu_Revive_HUDDownedIndicator", function(ply, target, time)
		if downedplayers[target] then
			if not IsValid(downedplayers[target]) or downedplayers[target].nzu_ReviveTime > ply.nzu_ReviveTime then
				downedplayers[target] = ply
			end
		end
	end)

	-- When players stop reviving, loop through all to find the next fastest one to take over, if any
	hook.Add("nzu_PlayerStoppedRevive", "nzu_Revive_HUDDownedIndicator", function(ply, target)
		-- Loop through all and find the next fastest to take over
		if downedplayers[target] then
			local min = math.huge
			local revivor
			for k,v in pairs(player.GetAll()) do
				if v.nzu_ReviveTarget == target then
					if v.nzu_ReviveTime < min then
						min = v.nzu_ReviveTime
						revivor = v
					end
				end
			end

			if IsValid(revivor) then
				downedplayers[target] = revivor
			else
				downedplayers[target] = NULL -- NULL, not NIL! That means it's true (for if statements), but no valid revivor
			end
		end
	end)

	function nzu.GetDownedPlayersRevivors() return downedplayers end
end


--[[-------------------------------------------------------------------------
Stat Registers
---------------------------------------------------------------------------]]
nzu.AddPlayerNetworkVar("Int", "NumRevives")
nzu.AddPlayerNetworkVar("Int", "NumDowns")

if SERVER then
	hook.Add("nzu_PlayerRevived", "nzu_Revive_ReviveStat", function(ply, savior)
		if IsValid(savior) then savior:SetNumRevives(savior:GetNumRevives() + 1) end
	end)

	hook.Add("nzu_PlayerDowned", "nzu_Revive_DownStat", function(ply)
		ply:SetNumDowns(ply:GetNumDowns() + 1)
	end)

	hook.Add("nzu_GameStarted", "nzu_Revive_StatReset", function()
		for k,v in pairs(player.GetAll()) do
			v:SetNumRevives(0)
			v:SetNumDowns(0)
		end
	end)
end