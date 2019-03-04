AddCSLuaFile()

local ENT = {}

ENT.Type = "anim"
ENT.Base = "base_entity"

function ENT:Initialize()
	self:SetModel("models/player/odessa.mdl")
	self:SetColor(Color(0,255,0))
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:DrawShadow(false)
end

scripted_ents.Register(ENT, "nzu_spawnpoint_zombie")

local TOOL = {}
TOOL.Category = "Basic"
TOOL.Name = "#tool.nzu_spawnpoint_zombie.name"

if CLIENT then
	language.Add("tool.nzu_spawnpoint_zombie.name", "Zombie Spawnpoint")
	language.Add("tool.nzu_spawnpoint_zombie.desc", "Creates a standard Zombie spawnpoint.")
end

function TOOL:LeftClick(trace)
	if SERVER then
		local e = ents.Create("nzu_spawnpoint_zombie")
		e:SetPos(trace.HitPos)
		e:Spawn()

		local ply = self:GetWeapon().Owner
		if IsValid(ply) then
			undo.Create("Zombie Spawnpoint")
				undo.SetPlayer(ply)
				undo.AddEntity(e)
			undo.Finish()
		end
	end
end

nzu.RegisterTool("spawnpoint_zombie", TOOL)