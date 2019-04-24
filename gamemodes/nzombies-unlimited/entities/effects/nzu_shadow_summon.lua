
-- This effect is taken from my Panic Ritual gamemode

local particledelay = 1.005
local spawntime = 0.25
local particlespeed = 10
local particlesize = 3
local radiusscale = 5

local colors = {
	--{100,0,150},
	{0,0,0},
	--{150,0,150},
	{0,0,0},
	--{50,0,150},
	{0,0,0},
	{50,0,100},
	{0,0,0},
	{20,0,50},
}

function EFFECT:Init(data)
	self.Pos = data:GetOrigin()
	self.Ang = data:GetAngles()
	self.Radius = data:GetRadius()
	self.Height = data:GetScale()
	local magn = data:GetMagnitude()
	self.ParticleSize = magn*particlesize -- Maybe later also change the number and not just size?

	self.NextParticle = 0
	self.KillTime = CurTime() + spawntime

	self.Emitter = ParticleEmitter(self.Pos)
end

local particles = {
	"particle/particle_noisesphere"
}

-- Run this on all particles to curve them around
local updaterate = 0.1

local particlefall = 0.25 -- How long to fall for
local steps = updaterate/particlefall -- How many steps it calculates in
local function calcvelz(h,x,t,s)
	--if true then return -500 end

	local pct = (1-x/t)
	if pct <= 0 then return 0 end
	local z = h * (pct*2 - s)
	return -z/t
end

local particlethink = function(p)
	local l = p:GetLifeTime()
	
	local z = 0
	if not p.DoneZ then
		z = calcvelz(p.Height, l, p.FallTime, p.Steps)
		if z == 0 then p.DoneZ = true end
	end

	
	local pct = math.Clamp((l - p.SpiralStart)/p.SpiralTime, 0, 1)
	local v = p:GetAngles():Right()*pct*p.CircleRadius
	v.z = z

	p:SetVelocity(v)

	p:SetNextThink(CurTime() + updaterate)
end

local numparticles = 50

-- Fall related
local minfalltime = 0.2
local maxfalltime = 0.6

-- Spiral related
local spiralstart = -0.5
local minspiraltime = 0.4
local maxspiraltime = 0.6

function EFFECT:Think()
	local ct = CurTime()
	if ct > self.NextParticle then
		for i = 1, numparticles do
			local p = self.Emitter:Add(particles[math.random(#particles)], self.Pos + Vector(0,0,self.Height))
			if (p) then
				local v = Vector(0, 0, -self.Height/particlefall)
				--p.OrigVel = v
				p.CircleRadius = self.Radius
				p.Height = self.Height
				p.FallTime = (maxfalltime/numparticles) * i + minfalltime
				p.Steps = updaterate/p.FallTime
				p.SpiralStart = p.FallTime + spiralstart
				p.SpiralTime = math.Rand(minspiraltime,maxspiraltime)
				--p.Z = 0
				--p:SetVelocity(v)
				p:SetColor(unpack(colors[math.random(#colors)]))
				p:SetLifeTime(0)
				p:SetDieTime(p.SpiralStart + p.SpiralTime*2)
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetStartSize(self.ParticleSize)
				p:SetEndSize(self.ParticleSize)
				p:SetRoll(math.Rand(0, 36)*10)
				p:SetAngles(Angle(0,math.random(0,360),0))

				--p:SetCollide(true)
				--p:SetBounce(1)
				p:SetAngleVelocity(Angle(0,90,0))
				--p:SetRollDelta(math.Rand(5,10))
				--p:SetAirResistance(self.Height/particlefall)
				--p:SetGravity(Vector(0, 0, -self.Height*particlespeed))

				p:SetThinkFunction(particlethink)
				p:SetNextThink(CurTime())
			end
		end
		self.NextParticle = ct + particledelay
	end

	
	if self.KillTime < ct then
		return false
	else
		return true
	end
end

function EFFECT:Render()
	
end
