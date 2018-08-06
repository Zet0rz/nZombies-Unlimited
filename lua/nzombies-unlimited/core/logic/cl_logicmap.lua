
local PANEL = {}
function PANEL:Init()
	self:SetSize(20,20)

end
function PANEL:Think()
	if IsValid(self.Entity) then
		local v = self.Entity:GetPos()
		self.Map:SetChildPos(self, v.x, v.y)
	else
		self:Remove()
	end
end
derma.DefineControl( "DMapEntity", "", PANEL, "DPanel" )

PANEL = {}
function PANEL:SpawnEntity(ent)
	if not self.Entities then self.Entities = {} end
	
	if self.Entities[ent] then return self.Entities[ent] end
	local p = vgui.Create("DMapEntity", self)
	p.Entity = ent
	p.Map = self
end

function PANEL:GetEntity(ent)
	return self.Entities and self.Entities[ent]
end
derma.DefineControl( "DMap", "", PANEL, "DScrollSheet" )

if NZ then
function NZ:Initialize()
	local T = GetNZUModule("spawnmenu")
	if not T then return end
	
	T:AddTab("Logic Map", function(pnl)
		local p = vgui.Create("DPanel")
		p:SetBackgroundColor(Color(50,50,50))
		
		local toolbar = p:Add("DScrollPanel", p)
		toolbar:SetWidth(200)
		toolbar:Dock(RIGHT)
		
		local map = p:Add("DMap", p)
		map:Dock(FILL)
		map:SetBackgroundColor(Color(75,75,75))
		--map:SetSize(500,500)
		
		nzu_map = map
		
		return p
	end, "icon16/control_repeat_blue.png", "Control Config Logic")
end
else
	local map = nzu_map
	map:SetBackgroundColor(Color(75,75,75))
	map:SetScale(0.1)
	
	local ply = map:GetEntity(LocalPlayer())
	if not ply then
		ply = map:SpawnEntity(LocalPlayer())
	end
end