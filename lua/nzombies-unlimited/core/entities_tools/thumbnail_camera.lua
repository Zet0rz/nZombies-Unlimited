local SWEP = {}

SWEP.PrintName = "Thumbnail Camera"
SWEP.Base = "gmod_camera"

function SWEP:PrimaryAttack()
	if not nzu.CurrentConfig then return end
	if self.Cooldown and self.Cooldown > CurTime() then return end

	self:DoShootEffect()

	if SERVER then
		if self.Owner:IsListenServerHost() then
			net.Start("nzu_screenshot")
			net.Send(self.Owner)
		end
	end

	self.Cooldown = CurTime() + 0.5
end

if SERVER then
	function SWEP:Think()
		if self.Cooldown and self.Cooldown < CurTime() then
			self.Owner:StripWeapon(self:GetClass())
		end
	end
	
	function SWEP:Holster()
		self.Owner:StripWeapon(self:GetClass())
	end
end
weapons.Register(SWEP, "nzu_thumbnail_camera")

if SERVER then
	util.AddNetworkString("nzu_screenshot")
	
	net.Receive("nzu_screenshot", function(len, ply)
		if game.SinglePlayer() or ply:IsListenServerHost() then
			ply:Give("nzu_thumbnail_camera")
		end
	end)
else
	local function docapture()
		local data = render.Capture({
			format = "jpeg",
			quality = 70,
			h = ScrH(),
			w = ScrW(),
			x = 0,
			y = 0,
		})

		local f = file.Open("nzombies-unlimited/localconfigs/"..nzu.CurrentConfig.Codename.."/thumb.jpg", "wb", "DATA")
		f:Write(data)
		f:Close()

		hook.Remove("PostRender", "nzu_screenshot")
	end
	net.Receive("nzu_screenshot", function()
		hook.Add("PostRender", "nzu_screenshot", docapture)
	end)
end