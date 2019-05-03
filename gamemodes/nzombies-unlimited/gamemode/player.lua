local PLAYER = FindMetaTable("Player")

local datatables = {}
function nzu.AddPlayerNetworkVar(type, name, extended)
	if not datatables[type] then datatables[type] = {} end
	local slot = table.insert(datatables[type], {name, extended})

	-- Install into all current players
	if SERVER then
		for k,v in pairs(player.GetAll()) do
			if v.nzu_dt then
				v:NetworkVar(type, slot, name, extended)
			end
		end
	elseif LocalPlayer().nzu_dt then
		LocalPlayer():NetworkVar(type, slot, name, extended)
	end
end

local notifies = {}
function nzu.AddPlayerNetworkVarNotify(name, func) -- Doesn't really work on client right now :/
	if not notifies[name] then notifies[name] = {} end
	table.insert(notifies[name], func)

	-- Install into all current players
	if SERVER then
		for k,v in pairs(player.GetAll()) do
			if v.nzu_dt then
				v:NetworkVarNotify(name, func)
			end
		end
	elseif LocalPlayer().nzu_dt then
		LocalPlayer():NetworkVarNotify(name, func)
	end
end

function nzu.InstallPlayerNetworkVars(ply)
	ply:InstallDataTable()

	for k,v in pairs(datatables) do
		for slot,data in pairs(v) do
			ply:NetworkVar(k, slot, data[1], data[2])
		end
	end

	for k,v in pairs(notifies) do
		for k2,v2 in pairs(v) do
			ply:NetworkVarNotify(k, v2)
		end
	end

	-- This will get overwritten if something else does ply:InstallDataTable() as the "dt" will be a new empty table
	-- We use this to check whether our default non-class network vars exist, or not
	ply.nzu_dt = true
end

hook.Add("OnEntityCreated", "nzu_PlayerNetworkVars", function(ply)
	if ply:IsPlayer() then
		nzu.InstallPlayerNetworkVars(ply)
	end
end)

--[[-------------------------------------------------------------------------
Models and stuff
---------------------------------------------------------------------------]]
if CLIENT then
	CreateConVar( "cl_playercolor", "0.24 0.34 0.41", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
	CreateConVar( "cl_weaponcolor", "0.30 1.80 2.10", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
	CreateConVar( "cl_playerskin", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin to use, if the model has any" )
	CreateConVar( "cl_playerbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups to use, if the model has any" )
end

if SERVER then
	-- Skin not actually set? Copied from Sandbox
	function PLAYER:UpdateModel()
		local c_mdl = self:GetInfo("cl_playermodel")
		local mdl = player_manager.TranslatePlayerModel(c_mdl)
		util.PrecacheModel(mdl)
		self:SetModel(mdl)
		self:SetPlayerColor(Vector(self:GetInfo("cl_playercolor")))

		local col = Vector(self:GetInfo("cl_weaponcolor"))
		if col:Length() == 0 then
			col = Vector(0.001, 0.001, 0.001)
		end
		self:SetWeaponColor(col)
	end
	
	hook.Add("PlayerInitialSpawn", "nzu_PlayerInit", function(ply)
		ply:UpdateModel()
	end)
end



--[[-------------------------------------------------------------------------
Unspawn/Spawn system
---------------------------------------------------------------------------]]

-- The "Unspawned". A mysterious class of people that seemingly has no interaction with the world, yet await their place in it.
team.SetUp(TEAM_UNASSIGNED, "Unspawned", Color(100,100,100))

TEAM_SURVIVORS = 1
team.SetUp(TEAM_SURVIVORS, "Survivors", Color(100,255,150))

function PLAYER:IsUnspawned()
	return self:Team() == TEAM_UNASSIGNED or self:Team() == TEAM_CONNECTING
end

if SERVER then
	util.AddNetworkString("nzu_playerunspawn")
	function PLAYER:Unspawn()
		if self:Alive() then self:KillSilent() end

		if not self:IsUnspawned() then
			self:SetTeam(TEAM_UNASSIGNED)
			net.Start("nzu_playerunspawn")
				net.WriteEntity(self)
				net.WriteBool(true)
			net.Broadcast()

			hook.Run("nzu_PlayerUnspawned", self)
		end
	end


	hook.Add("PlayerSpawn", "nzu_Player_Spawn", function(ply)
		if ply:IsUnspawned() and ply:Team() ~= TEAM_CONNECTING then
			ply:SetTeam(TEAM_SURVIVORS)
			net.Start("nzu_playerunspawn")
				net.WriteEntity(ply)
				net.WriteBool(false)
			net.Broadcast()

			hook.Run("nzu_PlayerInitialSpawned", ply)
		end
	end)

	-- This is basically dropping out and being on the main menu
	-- You can spectate from here too (later)
	
	function GM:PlayerInitialSpawn(ply)
		-- Is this timer really necessary? :(
		-- It doesn't seem to kill if not with the timer (probably cause it's before the spawn?)
		timer.Simple(0, function()
			if IsValid(ply) then
				if ply:Alive() then ply:KillSilent() end

				ply:SetTeam(TEAM_UNASSIGNED)
				net.Start("nzu_playerunspawn")
					net.WriteEntity(ply)
					net.WriteBool(true)
				net.Broadcast()

				hook.Run("nzu_PlayerUnspawned", ply)
			end
		end)
	end

	function GM:PlayerDeathThink() end -- Don't allow button press respawns
else
	net.Receive("nzu_playerunspawn", function()
		local ply = net.ReadEntity()
		local b = net.ReadBool()
		hook.Run(b and "nzu_PlayerUnspawned" or "nzu_PlayerInitialSpawned", ply)
	end)
end

-- No friendly fire!
hook.Add("EntityTakeDamage", "nzu_Player_NoFriendlyFire", function(ent, dmg)
	if ent:IsPlayer() and IsValid(dmg:GetAttacker()) and dmg:GetAttacker():IsPlayer() then return true end
end)