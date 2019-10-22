local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_entity"

-- Also allow spawnmenu spawning
ENT.Category = "nZombies Unlimited"
ENT.PrintName = "Wall Buy"
ENT.Author = "Zet0r"
ENT.Spawnable = true
ENT.Editable = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "WeaponClass", {
		KeyName = "weaponclass",
		Edit = {
			type = "Generic",
			title = "Weapon Class",
			order = 1,
			waitforenter = true
		}
	})
	self:NetworkVar("Int", 0, "Price", {
		KeyName = "price",
		Edit = {
			type = "Int",
			title = "Price",
			order = 2,
			min = 0, max = 5000
		}
	})
	self:NetworkVar("Bool", 0, "Bought")

	if SERVER then
		self:NetworkVarNotify("WeaponClass", self.WeaponClassChanged)
	end
end

local defaultmodel = "models/weapons/w_rif_m4a1.mdl"
local matrix = Matrix()
matrix:Rotate(Angle(0,90,0))
matrix:Scale(Vector(1,0.05,1))

local matrix2 = Matrix()
matrix2:Scale(Vector(0.05,1,1))
function ENT:GetWallBounds()
	local a,b = self:GetModelBounds()
	if b.x - a.x < b.y - a.y then
		return matrix2*a, matrix2*b, matrix2
	end
	return matrix*a, matrix*b, matrix
end

function ENT:Initialize()
	if SERVER then
		self:SetUseType(SIMPLE_USE)
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)

		local model = defaultmodel
		if self:GetWeaponClass() then
			local wep = weapons.GetStored(self:GetWeaponClass())
			if wep then model = wep.WM or wep.WorldModel end
		end
		
		local a,b = self:GetWallBounds()
		self:PhysicsInitBox(a,b)
		self:SetSolid(SOLID_OBB)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end
	else
		self:EnableMatrix("RenderMultiply", matrix)
	end
	self:DrawShadow(false)

	self:Precache()
end

function ENT:Precache()
	local class = self:GetWeaponClass()
	if class then
		local wep = weapons.GetStored(class)
		if wep then
			util.PrecacheModel(wep.WM or wep.WorldModel)
			if CLIENT then util.PrecacheModel(wep.VM or wep.ViewModel) end
		end
	end
end

if SERVER then
	function ENT:WeaponClassChanged(_, old, new)
		if old ~= new then
			local wep = weapons.GetStored(new)
			local model = wep and (wep.WM or wep.WorldModel) or defaultmodel

			if model ~= self:GetModel() then
				self:SetModel(model)
				local a,b = self:GetWallBounds()
				self:SetCollisionBounds(a,b)
			end

			self:SetBought(false)
		end
	end

	if NZU_NZOMBIES then
		function ENT:Use(activator)
			if IsValid(activator) and activator:IsPlayer() then
				local wep = activator:GetWeapon(self:GetWeaponClass())
				if IsValid(wep) then
					activator:Buy(math.Round(self:GetPrice()/2), function()
						wep:GiveMaxAmmo()
					end)
				else
					activator:Buy(self:GetPrice(), function()
						activator:Give(self:GetWeaponClass())
						self:SetBought(true)
					end)
				end
			end
		end
	else
		-- Sandbox: Just give the weapon
		function ENT:Use(activator)
			if IsValid(activator) and activator:IsPlayer() then
				activator:Give(self:GetWeaponClass())
				self:SetBought(true)
			end
		end
	end
end

if CLIENT then
	local outlines = {
		Vector(0, 0.5, 0.5),
		Vector(0, -0.5, -0.5),
		Vector(0, 0.5, -0.5),
		Vector(0, -0.5, 0.5),
	}
	local renderplane = Angle(0,90,90)
	function ENT:Draw()
		if halo.RenderedEntity() ~= self then
			render.ClearStencil()
			render.SetStencilEnable(true)
				render.SetStencilWriteMask(255)
				render.SetStencilTestMask(255)
				render.SetStencilReferenceValue(255)
				render.SetStencilFailOperation(STENCIL_ZERO)
				render.SetStencilZFailOperation(STENCIL_ZERO)
				render.SetStencilPassOperation(STENCIL_REPLACE)
				render.SetStencilCompareFunction(STENCIL_ALWAYS)

				-- Mark all pixels drawn by these offset positions with 255
				render.SetBlend(0)
				for k,v in pairs(outlines) do
					self:SetRenderOrigin(self:LocalToWorld(v*1))
					self:InvalidateBoneCache()
					self:DrawModel()
					self:SetRenderOrigin(nil)
				end

				-- Render the central position to remove stencil writes
				render.SetStencilPassOperation(STENCIL_ZERO)
				self:SetRenderOrigin(nil)
				self:SetupBones()
				self:DrawModel()

				-- Draw the chalk texture over itself with the marked pixels
				render.SetStencilCompareFunction(STENCIL_EQUAL)

				local a,b = self:GetRenderBounds()
				local x1,x2,y1,y2 = b.y,a.y,-a.z,-b.z
				cam.Start3D2D(self:GetPos(), self:LocalToWorldAngles(renderplane), 1)
					surface.SetDrawColor(255,255,255) -- TODO: Change this later to a chalk-like material
					surface.DrawRect(x1 + 4,y1 + 4,-x1 + x2 - 8,-y1 + y2 - 8)
					--surface.DrawRect(x1,y1,-x1 + x2,-y1 + y2)
				cam.End3D2D()

			render.SetBlend(1)
			render.SetStencilEnable(false)
			if self:GetBought() then self:DrawModel() end
		else
			self:DrawModel()
		end		
	end
	ENT.DrawTranslucent = ENT.Draw

	-- Display our own text :D
	function ENT:GetTargetIDText()
		if self.SavedClass ~= self:GetWeaponClass() then
			local wep = weapons.GetStored(self:GetWeaponClass())
			if wep then
				self.WeaponName = " "..wep.PrintName.." "
			else
				self.WeaponName = " UNKNOWN WEAPON "
			end
			self.SavedClass = self:GetWeaponClass()
		end

		if LocalPlayer():HasWeapon(self:GetWeaponClass()) then
			return self.WeaponName .. "Ammo ", TARGETID_TYPE_BUY, math.Round(self:GetPrice()/2)
		else
			return self.WeaponName, TARGETID_TYPE_BUY, self:GetPrice()
		end
	end
	
	function ENT:Think()
		if self:GetModel() ~= self.LastModel then
			local a,b,matrix = self:GetWallBounds()
			self:SetRenderBounds(a,b)
			self:EnableMatrix("RenderMultiply", matrix)
			self.LastModel = self:GetModel()
		end
	end
end
scripted_ents.Register(ENT, "nzu_wallbuy")

--[[-------------------------------------------------------------------------
Mismatch module
---------------------------------------------------------------------------]]
nzu.RegisterMismatch("Wall Buys", {
	Collect = function()
		local t = {}
		for k,v in pairs(ents.FindByClass("nzu_wallbuy")) do
			if not weapons.GetStored(v:GetWeaponClass()) then
				table.insert(t, v)
			end
		end
		if #t > 0 then return t end
	end,
	Write = function(t)
		if SERVER then -- Servers write just the wrong classes
			net.WriteUInt(#t, 16)
			for k,v in ipairs(t) do
				if IsValid(v) then
					net.WriteEntity(v)
					net.WriteString(v:GetWeaponClass())
				end
			end
		else -- Clients write the wrong class and the replacement class
			net.WriteUInt(table.Count(t), 16)
			for k,v in pairs(t) do
				net.WriteUInt(k, 16)
				net.WriteString(v)
			end
		end
	end,
	Read = function()
		local t = {}
		local num = net.ReadUInt(16)
		if CLIENT then -- Clients receive just the wrong classes, but generate the map table
			for i = 1,num do
				local id = net.ReadUInt(16)
				t[id] = net.ReadString()
			end
		else -- Servers read the table of entities and their new class
			for i = 1,num do
				local ent = net.ReadEntity()
				local class = net.ReadString()
				t[ent] = class
			end
		end
		return t
	end,
	Apply = function(t)
		for k,v in pairs(t) do
			if v == "" then k:Remove() else k:SetWeaponClass(v) end
		end
	end,
	BuildPanel = function(parent, t)
		local dlist = vgui.Create("DListView", parent)
		dlist:AddColumn("Invalid Wall Buy")
		dlist:AddColumn("Replacement Weapon")

		local weps = {}
		for k,v in pairs(t) do
			local ent = Entity(k)
			local pnl = nzu.ExtensionSettingTypePanel("Weapon", parent)
			pnl:SetValue(v)
			dlist:AddLine(v .. " (".. (IsValid(ent) and ent:GetPrice() or "Can't get Price")..")", pnl):SetTall(100)

			weps[k] = pnl
		end

		-- Collect the corrected data when the Apply button is pressed
		function dlist:GetMismatch()
			local tbl = {}
			for k,v in pairs(weps) do
				tbl[k] = v:GetValue()
			end
			return tbl
		end

		return dlist
	end,
	Icon = "icon16/gun.png",
})

if not NZU_SANDBOX then return end
--[[-------------------------------------------------------------------------
Tool for spawning wall buys, browses weapon classes through filters
---------------------------------------------------------------------------]]
local TOOL = {}
TOOL.Category = "Weapons"
TOOL.Name = "#tool.nzu_tool_wallbuy.name"

TOOL.ClientConVar = {
	["class"] = "weapon_medkit",
	["price"] = "1000",
}

function TOOL:LeftClick(trace)
	if SERVER then
		local ply = self:GetOwner()

		local e = ents.Create("nzu_wallbuy")
		e:SetPos(trace.HitPos + trace.HitNormal*0.5)
		e:SetAngles(trace.HitNormal:Angle())
		e:Spawn()
		e:SetWeaponClass(self:GetClientInfo("class"))
		e:SetPrice(self:GetClientNumber("price"))
		
		if IsValid(ply) then
			undo.Create("Wall Buy")
				undo.SetPlayer(ply)
				undo.AddEntity(e)
			undo.Finish()
		end
	end
	return true
end

function TOOL:RightClick(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_wallbuy" then
		if SERVER then
			local tr = util.TraceLine({
				start = trace.HitPos,
				endpos = trace.HitPos + trace.Normal * 100,
				filter = trace.Entity
			})

			if tr.Hit and tr.HitNormal then
				trace.Entity:SetPos(tr.HitPos + tr.HitNormal*0.5)
				trace.Entity:SetAngles(tr.HitNormal:Angle())
			else
				self:GetOwner():ChatPrint("Couldn't find wall behind Wall Buy to align to.")
			end
		end
		return true
	end
end

function TOOL:Reload(trace)
	if IsValid(trace.Entity) and trace.Entity:GetClass() == "nzu_wallbuy" then
		if SERVER then trace.Entity:Remove() end
		return true
	end
end

if CLIENT then
	TOOL.Information = {
		{name = "left"},
		{name = "right"},
		--{name = "reload"}
	}

	language.Add("tool.nzu_tool_wallbuy.name", "Wall Buy")
	language.Add("tool.nzu_tool_wallbuy.desc", "Creates a Wall Buy of the specified weapon that can be bought by players in-game.")

	language.Add("tool.nzu_tool_wallbuy.left", "Create Wall Buy")
	language.Add("tool.nzu_tool_wallbuy.right", "Align with wall")
	language.Add("tool.nzu_tool_wallbuy.reload", "Remove Wall Buy")

	function TOOL.BuildCPanel(panel)
		panel:Help("Spawn a Wall Buy for the specified weapon and with the specified price. Players can buy these in-game to acquire the weapon.")

		local slider = panel:NumSlider("Price", "nzu_tool_wallbuy_price", 0, 5000, 0)
		function slider:TranslateSliderValues(x,y) -- Round to nearest 100
			local val = self.Scratch:GetMin() + x*self.Scratch:GetRange()

			val = math.Round(val, -2)

			self:SetValue(val)
			return self.Scratch:GetFraction(), y
		end

		local wep = vgui.Create("DSearchComboBox", panel)
		local lbl = Label("Weapon", panel)
		lbl:SetDark(true)
		panel:AddItem(lbl, wep)
		wep:Dock(TOP)
		
		for k,v in pairs(weapons.GetList()) do
			wep:AddChoice((v.PrintName or "").." ["..v.ClassName.."]", v.ClassName)
		end

		wep:SetConVar("nzu_tool_wallbuy_class")
		wep:SetAllowCustomInput(true)

		-- Spacer added just so the context menu is a bit nicer with space for the dropdown
		local spacer = vgui.Create("Panel", panel)
		spacer:SetTall(200)
		panel:AddItem(spacer)
	end
end

nzu.RegisterTool("wallbuy", TOOL)