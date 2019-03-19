local PLAYER = FindMetaTable("Player")
local ENTITY = FindMetaTable("Entity")
nzu.AddPlayerNetworkVar("Bool", "IsDowned") -- So prediction can work with it too

local bleedouttime = 45 -- Seconds




--[[-------------------------------------------------------------------------
Basic Revive state
---------------------------------------------------------------------------]]
if SERVER then
	util.AddNetworkString("nzu_playerdowned") -- Server: Broadcast that a player was downed, triggering their

	function PLAYER:DownPlayer()
		if not self:GetIsDowned() then
			self:SetHealth(1) -- Is this a nice touch or nah?
			self:SetIsDowned(true)
			self.nzu_DownedTime = CurTime()

			net.Start("nzu_playerdowned")
				net.WriteEntity(self)
				net.WriteBool(true)
				net.WriteFloat(self.nzu_DownedTime)
			net.Broadcast()

			hook.Run("nzu_PlayerDowned", self)

			self:AddUntargetability("Downed")
		end
	end

	function PLAYER:RevivePlayer(savior)
		if self:GetIsDowned() then
			self:SetHealth(100)
			self:SetIsDowned(false)
			self.nzu_DownedTime = nil

			net.Start("nzu_playerdowned")
				net.WriteEntity(self)
				net.WriteBool(false)
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
end

if CLIENT then
	net.Receive("nzu_playerdowned", function()
		local ply = net.ReadEntity()
		if net.ReadBool() then
			ply.nzu_DownedTime = net.ReadFloat()
			hook.Run("nzu_PlayerDowned", self)
		else
			ply.nzu_DownedTime = nil
			hook.Run("nzu_PlayerRevived", self)
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
			local passed = CurTime() - ply.nzu_DownedTime
			if passed > bleedouttime then
				--ply:Kill() -- Just using Kill() is how to kill a downed player
			end
		end
	end)

	-- Clear revive status on finally dying (such as bleeding out)
	hook.Add("PostPlayerDeath", "nzu_Revive_PlayerDeathCleanup", function(ply)
		if ply:GetIsDowned() then
			ply:SetIsDowned(false)
			ply.nzu_DownedTime = nil
		end
	end)

	-- Control downing through damage
	hook.Add("EntityTakeDamage", "nzu_Revive_DownPlayer", function(ent, dmg)
		if ent:IsPlayer() then
			if ent:GetIsDowned() then
				-- Downed player, block any damage
				return true
			else
				if dmg:GetDamage() >= ent:Health() then
					ent:DownPlayer()
					return true
				end
			end
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
	return 5 -- Change this to hook later? Or some system to change player revive times (for perks, powerups, etc)
end

if SERVER then
	util.AddNetworkString("nzu_playerreviving") -- Server: Notify clients that a player is being revived by another

	function PLAYER:StartReviving(target)
		self.nzu_ReviveTime = CurTime() + time
		self.nzu_ReviveTarget = ent
		hook.Run("nzu_PlayerStartedRevive", self, target, time)

		net.Start("nzu_playerreviving")
			net.WriteEntity(self)
			net.WriteBool(true)
			net.WriteFloat(self.nzu_ReviveTime)
			net.WriteEntity(target)
		net.Broadcast()
	end

	function PLAYER:StopReviving()
		self.nzu_ReviveTime = nil
		self.nzu_ReviveTarget = nil

		net.Start("nzu_playerreviving")
			net.WriteEntity(self)
			net.WriteBool(false)
		net.Broadcast()

		self.nzu_ReviveBlock = CurTime() + 0.1

		hook.Run("nzu_PlayerStoppedRevive", self)
	end

	-- Find players for use
	local reviverange = 100
	local quicktrace = util.QuickTrace
	hook.Add("FindUseEntity", "nzu_Revive_UsePlayers", function(ply, ent)
		-- Optimization. We already block downed players from using below, but we may as well save the trace too
		if not ply:GetIsDowned() then
			local tr = quicktrace(ply:EyePos(), ply:GetAimVector()*reviverange, ply)
			local target = tr.Entity

			if IsValid(target) and target:CanBeRevived() and target:GetIsDowned() then
				return target
			elseif ply.nzu_ReviveTarget then
				ply:StopReviving()
			end 
		end
	end)

	-- Downed players can't use anything
	hook.Add("PlayerUse", "nzu_Revive_RevivePlayers", function(ply, ent)
		if ply:GetIsDowned() then return false end

		if IsValid(ent) and ent:CanBeRevived() and ent:GetIsDowned() and (not ply.nzu_ReviveBlock or ply.nzu_ReviveBlock < CurTime()) then
			if ply.nzu_ReviveTarget ~= ent then
				local time = ply:GetReviveTime()
				if time > 0 then
					ply:StartReviving(ent)
				else
					hook.Run("nzu_PlayerStartedRevive", ply, ent, time) -- Hack for instant rezzes, still call hook but save the networking
					ent:RevivePlayer(ply)
				end
				print("Started reviving", ply, ent, time)
			elseif CurTime() >= ply.nzu_ReviveTime then
				ent:RevivePlayer(ply)
				ply:StopReviving()
			end
		elseif ply.nzu_ReviveTarget then
			ply:StopReviving()
		end
	end)

	-- Also stop for E
	hook.Add("KeyRelease", "nzu_Revive_StopHoldingE", function(ply, key)
		if key == IN_USE and ply.nzu_ReviveTarget then
			ply:StopReviving()
		end
	end)
end

if CLIENT then
	net.Receive("nzu_playerreviving", function()
		local ply = net.ReadEntity()
		if net.ReadBool() then
			ply.nzu_ReviveTime = net.ReadFloat()
			ply.nzu_ReviveTarget = net.ReadEntity()

			hook.Run("nzu_PlayerStartedRevive", ply, ply.nzu_ReviveTarget, ply.nzu_ReviveTime - CurTime())
		else
			ply.nzu_ReviveTime = nil
			ply.nzu_ReviveTarget = nil
			hook.Run("nzu_PlayerStoppedRevive", ply)
		end
	end)
end






--[[-------------------------------------------------------------------------
Movement & Aiming for Downed Players
---------------------------------------------------------------------------]]
local visionlowered = Vector(0,0,0)
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
	hook.Add("CalcView", "nzu_Revive_DownedView", function(ply, pos, ang, fov, znear, zfar)
		if ply:GetIsDowned() then
			local view = {fov = fov, znear = znear, zfar = zfar}
			view.origin = pos + visionlowered
			view.angles = ang + rotang

			return view
		end
	end)

	hook.Add("CalcViewModelView", "nzu_Revive_DownedViewmodel", function(wep, vm, oldp, olda, pos, ang)
		if LocalPlayer():GetIsDowned() then
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

local cyclex, cycley = 0.7,0.75
local hullchange = Vector(0,0,25)
hook.Add("UpdateAnimation", "nzu_Revive_DownedAnimation", function(ply, vel, seqspeed)
	if ply:GetIsDowned() then
		local movement = 0

		local len = vel:Length2D()
		if len > 1 then
			movement = len/seqspeed
		else
			local cycle = ply:GetCycle()
			if cycle < cyclex or cycle > cycley then
				movement = 5
			end
		end

		ply:SetPoseParameter("move_x", -1)
		ply:SetPlaybackRate(movement)

		if not ply.nzu_DownedAnim then
			local x,y = ply:GetHull()
			ply:SetHull(x + hullchange, y + hullchange)
			ply.nzu_DownedAnim = true
		end
		return true
	elseif ply.nzu_DownedAnim then
		ply:SetPos(ply:GetPos() + hullchange)
		ply:ResetHull()
		ply.nzu_DownedAnim = nil
	end
end)

if CLIENT then
	local loweredpos = Vector(0,0,0)
	hook.Add("PrePlayerDraw", "nzu_Revive_DownedAnimation", function(ply)
		if ply:GetIsDowned() then
			ply:InvalidateBoneCache()
			ply:SetNetworkOrigin(ply:GetPos() - loweredpos)
			local ang = ply:GetAngles()
			ply:SetRenderAngles(Angle(-30, ang[2], ang[3]))
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) then wep:InvalidateBoneCache() end
		end
	end)
end