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
			hook.Run("nzu_PlayerDowned", ply)
		else
			ply.nzu_DownedTime = nil
			hook.Run("nzu_PlayerRevived", ply)
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

	function PLAYER:StartReviving(target, time2)
		if self.nzu_ReviveLocked then return end

		local time = time2 or self:GetReviveTime()
		if time > 0 then
			self.nzu_ReviveTime = CurTime() + time
			self.nzu_ReviveTarget = target
			self.nzu_ReviveStartTime = CurTime()
			hook.Run("nzu_PlayerStartedRevive", self, target, time)

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

		self.nzu_ReviveBlock = CurTime() + 0.1

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
				local tr = quicktrace(ply:EyePos(), ply:GetAimVector()*reviverange, ply)
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
	hook.Add("PlayerUse", "nzu_Revive_RevivePlayers", function(ply, ent)
		if ply:GetIsDowned() then return false end

		if not ply.nzu_ReviveLocked then
			if IsValid(ent) and ent:CanBeRevived() and ent:GetIsDowned() and (not ply.nzu_ReviveBlock or ply.nzu_ReviveBlock < CurTime()) then
				if ply.nzu_ReviveTarget ~= ent then
					ply:StartReviving(ent)
				--elseif CurTime() >= ply.nzu_ReviveTime then
					--ent:RevivePlayer(ply)
					--ply:StopReviving()
				end
			elseif ply.nzu_ReviveTarget then
				ply:StopReviving()
			end
		end
	end)

	-- Also stop for E
	hook.Add("KeyRelease", "nzu_Revive_StopHoldingE", function(ply, key)
		if key == IN_USE and ply.nzu_ReviveTarget and not ply.nzu_ReviveLocked then
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

local cyclex, cycley = 0.6,0.65
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

		return true
	end
end)

if CLIENT then
	local loweredpos = Vector(20,0,-30)
	local mat = Matrix()
	mat:SetTranslation(loweredpos)
	mat:Rotate(Angle(-30,0,0))

	local mat2 = Matrix()

	hook.Add("PrePlayerDraw", "nzu_Revive_DownedAnimation", function(ply)
		if ply:GetIsDowned() then
			if not ply.nzu_DownedAnim then
				ply:EnableMatrix("RenderMultiply", mat)
				ply.nzu_DownedAnim = true
			end
			--local ang = ply:GetAngles()
			--ply:SetRenderAngles(Angle(-30, ang[2], ang[3]))
			--ply:SetRenderOrigin(ply:GetPos() - loweredpos + ang:Forward()*20)
			
			--ply:InvalidateBoneCache()
			
			--local wep = ply:GetActiveWeapon()
			--if IsValid(wep) then wep:InvalidateBoneCache() end
		elseif ply.nzu_DownedAnim then
			ply:DisableMatrix("RenderMultiply")
			ply.nzu_DownedAnim = nil
		end
	end)
end




--[[-------------------------------------------------------------------------
Clientside HUD Drawing
---------------------------------------------------------------------------]]
if CLIENT then
	nzu.RegisterHUDComponentType("ReviveProgress")
	nzu.RegisterHUDComponentType("DownedIndicator")

	local localplayer
	local isbeingrevived = false
	local downedplayers = {}
	hook.Add("nzu_PlayerDowned", "nzu_Revive_HUDDownedIndicator", function(ply)
		if ply ~= LocalPlayer() then
			downedplayers[ply] = NULL
		end
	end)

	local function playernolongerdown(ply)
		if ply ~= LocalPlayer() then
			downedplayers[ply] = nil
		end
	end
	hook.Add("nzu_PlayerRevived", "nzu_Revive_HUDDownedIndicator", playernolongerdown)
	hook.Add("EntityRemoved", "nzu_Revive_HUDDownedIndicator", playernolongerdown)

	-- When players start reviving a target, check to see if they're faster and update the revivor if so
	hook.Add("nzu_PlayerStartedRevive", "nzu_Revive_HUDDownedIndicator", function(ply, target, time)
		if target == LocalPlayer() then -- If LocalPlayer is the one being revived
			if not isbeingrevived then -- If we were not previously being revived, immediately overwrite
				localplayer = ply
				isbeingrevived = true
			elseif not IsValid(localplayer) or localplayer.nzu_ReviveTime > ply.nzu_ReviveTime then -- Else only if faster than previous revivor
				localplayer = ply
			end
		elseif ply == LocalPlayer() and not isbeingrevived then -- If we're reviving, and we're also not being revived, change our target
			localplayer = target
		end

		if downedplayers[target] then
			if not IsValid(downedplayers[target]) or downedplayers[target].nzu_ReviveTime > ply.nzu_ReviveTime then
				downedplayers[target] = ply
			end
		end
	end)

	-- When players stop reviving, loop through all to find the next fastest one to take over, if any
	hook.Add("nzu_PlayerStoppedRevive", "nzu_Revive_HUDDownedIndicator", function(ply, target)
		if ply == LocalPlayer() or target == LocalPlayer() then -- We're stopping being revived or stopping to revive ourselves
			local min = math.huge
			local revivor
			for k,v in pairs(player.GetAll()) do
				if v.nzu_ReviveTarget == LocalPlayer() then -- Loop through all. If any are reviving us, that takes priority (for fastest)
					if v.nzu_ReviveTime < min then
						min = v.nzu_ReviveTime
						revivor = v
					end
				end
			end

			--print(revivor)

			if IsValid(revivor) then -- Someone's reviving us
				localplayer = revivor
				isbeingrevived = true
			elseif IsValid(LocalPlayer().nzu_ReviveTarget) then -- We're reviving someone else
				localplayer = LocalPlayer().nzu_ReviveTarget
				isbeingrevived = false
			else
				localplayer = nil
				isbeingrevived = false -- Neither is true
			end
		end

		-- For other players, loop through all and find the next fastest to take over
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

	local dopaint = nzu.DrawHUDComponent
	-- Draw downed indicator on other players
	hook.Add("HUDPaint", "nzu_Revive_DownedIndicator", function()
		for k,v in pairs(downedplayers) do
			dopaint("DownedIndicator", k, v)
		end
		--dopaint("DownedIndicator", Entity(2))
	end)

	-- Draw revive progress for local player
	hook.Add("HUDPaint", "nzu_Revive_ReviveProgress", function()
		if IsValid(localplayer) then
			dopaint("ReviveProgress", localplayer, isbeingrevived)
		end
	end)

	--[[local getplys = team.GetPlayers
	hook.Add("HUDPaint", "nzu_Revive_DownedIndicator", function()
		local lp = LocalPlayer()

		if not lp:IsUnspawned() then
			local plys = getplys(lp:Team())

			local torevive = {}
			local maxprogress = {}
			for k,v in pairs(plys) do
				if v:GetIsDowned() then table.insert(torevive, v) end
				if v.nzu_ReviveTarget then
					local remain = v.nzu_ReviveTime
				end
			end
		end
	end)]]
end



--[[-------------------------------------------------------------------------
HUD Components
---------------------------------------------------------------------------]]
if CLIENT then
	local mat = Material("nzombies-unlimited/hud/points_shadow.png")
	local mat2 = Material("nzombies-unlimited/hud/points_glow.vmt")

	nzu.RegisterHUDComponent("ReviveProgress", "Unlimited", {
		Draw = function(ply, isbeingrevived)
			local lp = LocalPlayer()
			local w,h = ScrW()/2 ,ScrH()
			local revivor = isbeingrevived and ply or LocalPlayer()

			local diff = revivor.nzu_ReviveTime - revivor.nzu_ReviveStartTime
			local pct = (CurTime() - revivor.nzu_ReviveStartTime)/diff
			if pct > 1 then pct = 1 end

			surface.SetDrawColor(0,0,0)
			surface.DrawRect(w - 150, h - 300, 300, 20)

			surface.SetDrawColor(255,255,255)
			surface.DrawRect(w - 145, h - 295, 290*pct, 10)

			if isbeingrevived then
				draw.SimpleTextOutlined("Being revived by "..ply:Nick(), "DermaLarge", w, h - 310, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
			else
				draw.SimpleTextOutlined("Reviving "..ply:Nick(), "DermaLarge", w, h - 310, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 2, color_black)
			end
		end
	})

	local REVIVEfont = "nzu_Font_Revive"
	local downedindicator = Vector(0,0,25)
	local point = Material("gui/point.png")
	local revivetext = "REVIVE"
	local revivebarheight = 10
	local outlines = 5
	local waveheight = 40
	local pointheight = 15
	
	nzu.RegisterHUDComponent("DownedIndicator", "Unlimited", {
		Draw = function(ply, revivor)
			local pos = (ply:GetPos() + downedindicator):ToScreen()
			if pos.visible then
				local x,y = pos.x,pos.y
				surface.SetFont(REVIVEfont)
				local w,h = surface.GetTextSize(revivetext)

				local w2 = w + outlines*2
				local x2 = x - w/2 - outlines
				local y2 = y - 6

				surface.SetMaterial(mat)
				surface.SetDrawColor(0,0,0,255)
				surface.DrawTexturedRectRotated(x, y - h, waveheight, w2, 90)

				surface.DrawRect(x2, y2, w2, revivebarheight)

				surface.SetMaterial(point)
				surface.DrawTexturedRect(x2, y2 + revivebarheight, w2, pointheight)
				

				if IsValid(revivor) then
					local diff = revivor.nzu_ReviveTime - revivor.nzu_ReviveStartTime
					local pct = (CurTime() - revivor.nzu_ReviveStartTime)/diff

					surface.SetDrawColor(255,255,255)
					surface.SetTextColor(255,255,255)
					surface.DrawRect(x2 + 4, y2 + 3, (w2 - 8) * pct, revivebarheight - 6)
				elseif ply.nzu_DownedTime then
					local pct = (1 - (CurTime() - ply.nzu_DownedTime)/bleedouttime)*255
					surface.SetDrawColor(255,pct,0)
					surface.SetTextColor(255,pct,0)
					surface.DrawRect(x2 + 4, y2 + 3, w2 - 8, revivebarheight - 6)
				end
				surface.DrawTexturedRect(x2 + 7, y2 + revivebarheight, w2 - 14, pointheight - 4)
				surface.SetMaterial(mat2)
				surface.DrawTexturedRectRotated(x, y - h, waveheight, w2, 90)
				
				surface.SetTextPos(pos.x - w/2, pos.y - h)
				surface.DrawText(revivetext)
			end
		end
	})
end