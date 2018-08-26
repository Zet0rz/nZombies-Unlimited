--[[
	Structure:
	category, id, data = {
		Class = string,
		PrintName = string,
		Material = png or model path,
		SpawnFunction = function(ent),
		Extension = string, <-- have this?
	}

	Category:
	name, icon
]]

nzu.AddSpawnmenuEntityCategory("Test Category", "icon16/plugin.png")
nzu.AddSpawnmenuEntity("Test Category", "greenball", {
	Class = "sent_ball",
	PrintName = "Green Ball",
	Material = "entities/weapon_pistol.png",
	SpawnFunction = function(ent, ply, tr)
		ent:SetBallSize(10)
		ent:SetBallColor(Vector(0,1,0))
	end,
})
nzu.AddSpawnmenuEntity("Test Category", "redball", {
	Class = "sent_ball",
	PrintName = "Red Big Ball",
	Material = "entities/weapon_crowbar.png",
	SpawnFunction = function(ent, ply, tr)
		ent:SetBallSize(20)
		ent:SetBallColor(Vector(1,0,0))
	end,
})
nzu.AddSpawnmenuEntity("Test Category", "blueball", {
	Class = "sent_ball",
	PrintName = "Blue Small Ball",
	Material = "models/alig96/perks/cherry/cherry.mdl",
	SpawnFunction = function(ent, ply, tr)
		ent:SetBallSize(5)
		ent:SetBallColor(Vector(0,0,1))
	end,
})
nzu.AddSpawnmenuEntity("New Category", "randomball", {
	PrintName = "High Random Ball",
	Material = "models/alig96/perks/phd/phdflopper.mdl",
	SpawnFunction = function(ent, ply, tr)
		local ent = ents.Create("sent_ball")
		ent:SetPos(tr.HitPos + tr.HitNormal*100)
		ent:SetBallColor(VectorRand())
		ent:SetOwner(ply)
		ent:Spawn()

		return ent
	end,
})