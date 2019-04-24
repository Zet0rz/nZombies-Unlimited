local arcpoints = 4
local arcspeed = 30
local arctaildelay = 0.2

local col = Color(255,255,255)
local col2 = Color(0,0,0)
local arcsize = 10

local mat_lightning = Material("effects/tool_tracer")
local mat_center = Material("sprites/physbeama")

local risetime = 0.25
local risespeed = 1000

function EFFECT:Init(data)
	local life = data:GetScale()
	self.Lifetime = CurTime() + (life > 0 and life or 2)

	local ent = data:GetEntity()
	if IsValid(ent) then
		self.Entity = ent
		self:SetParent(ent)
		self.Pos = ent:WorldSpaceCenter()
		--self:SetLocalPos(data:GetOrigin())

		self.RisePos = Vector(0,0,0)
		self.RiseStart = self.Lifetime - risetime
	else
		--self:SetPos(data:GetOrigin())
		self.Pos = data:GetOrigin()
		self.Entity = nil
	end
	self:SetPos(self.Pos)

	self.ArcFrequency = 0.05/data:GetMagnitude()
	if self.ArcFrequency <= 0 then self.ArcFrequency = 0.05 end	

	self.Arcs = {}
	self.Radius = data:GetRadius()
	if self.Radius <= 0 then
		if IsValid(self.Entity) then
			local a,b = self.Entity:GetModelBounds()*self.Entity:GetModelScale()
			self.Radius = a:Distance(self.Entity:WorldSpaceCenter() - self.Entity:GetPos())*0.9
		else
			self.Radius = 50
		end
	end

	self:SetRenderBounds(Vector(self.Radius,self.Radius,self.Radius), Vector(self.Radius,self.Radius,self.Radius), Vector(50, 50, 50))
	self.NextArc = 0
end

function EFFECT:Think()
	local ct = CurTime()
	--if ct > self.Lifetime then return false end

	local fr = FrameTime()
	if ct > self.NextArc and ct <= self.Lifetime then
		local arc = {}

		local v = VectorRand():GetNormalized()*self.Radius -- Random direction
		for i = 1,arcpoints do
			local p1 = Vector(v)
			v:Rotate(Angle(math.random(0,30), math.random(0,30), math.random(0,30)))

			local dir = v - p1
			local life = dir:Length()/arcspeed

			arc[i] = {Start = p1, Dir = dir, Time = life}
		end

		table.insert(self.Arcs, {Segments = arc, Head = 1, Tail = 1, TailStart = ct + arctaildelay*math.Rand(0.5,1.5), Pct1 = 0, Pct2 = 0})
		self.NextArc = ct + self.ArcFrequency
	end

	for k,v in pairs(self.Arcs) do
		local head = v.Segments[v.Head]
		local tail = v.Segments[v.Tail]

		if head then
			local res = v.Pct1 + (fr*arcspeed)/head.Time
			if res > 1 then
				v.Pct1 = 0
				v.Head = v.Head + 1
			else
				v.Pct1 = res
			end
		end

		if tail and ct > v.TailStart then
			local res = v.Pct2 + (fr*arcspeed)/tail.Time
			if res > 1 then
				-- Remove the arc if the tail is the last segment
				if not v.Segments[v.Tail + 1] then
					self.Arcs[k] = nil
					if ct > self.Lifetime and not next(self.Arcs) then return false end -- Kill if the table is empty
				else
					v.Pct2 = 0
					v.Tail = v.Tail + 1
				end
			else
				v.Pct2 = res
			end
		end
	end

	return true
end

function EFFECT:Render()
	local ct = CurTime()

	if IsValid(self.Entity) then
		self.Pos = self.Entity:WorldSpaceCenter()

		local origin = self.Entity:GetNetworkOrigin()
		if ct > self.RiseStart then
			self.RisePos.z = self.RisePos.z + risespeed*FrameTime()
			origin = origin + self.RisePos
		end
		self.Entity:SetRenderOrigin(origin + VectorRand())
	end

	
	for k,v in pairs(self.Arcs) do
		for k2,v2 in pairs(v.Segments) do
			if k2 <= v.Head and k2 >= v.Tail then
				local p1,p2

				-- Front position
				if k2 == v.Head then
					p2 = v2.Start + v2.Dir*v.Pct1
				else
					p2 = v2.Start + v2.Dir
				end

				-- Front position
				if k2 == v.Tail then
					p1 = v2.Start + v2.Dir*v.Pct2
				else
					p1 = v2.Start
				end

				local texcoord = math.Rand(0,1)

				render.SetMaterial(mat_lightning)
				render.DrawBeam(
					self.Pos + p1,
					self.Pos + p2,
					arcsize,
					texcoord,
					texcoord + v2.Dir:Length()/128,
					col
				)

				--[[render.SetMaterial(mat_center)
				render.DrawBeam(
					self.Pos + p1,
					self.Pos + p2,
					2,
					texcoord,
					texcoord + v2.Dir:Length()/128,
					col
				)]]
			end
		end
	end
end