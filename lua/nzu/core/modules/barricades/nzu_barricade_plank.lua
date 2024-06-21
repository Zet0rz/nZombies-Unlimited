local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"

-- Allow spawnmenu too
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Barricade"
ENT.Author = "Zet0r"
ENT.Spawnable = true
--ENT.Editable = true

ENT.RepairSound = "nzu_barricade_postrepair"
sound.Add({
	name = "nzu_barricade_postrepair",
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 80,
	pitch = {90,110},
	sound = "nzu/barricade/repair.wav"
})

--[[-------------------------------------------------------------------------
Initialization
---------------------------------------------------------------------------]]



--[[-------------------------------------------------------------------------
Saving/Loading
---------------------------------------------------------------------------]]



scripted_ents.Register(ENT, "nzu_barricade")