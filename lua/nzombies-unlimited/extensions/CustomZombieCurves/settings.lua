local EXTENSION = nzu.Extension()

local settings = {
	-- Round
	["ZombieNumberRoundScale"] = {
		Type = TYPE_NUMBER,
		Default = 0.15,
	},
	["ZombieNumberBase"] = {
		Type = TYPE_NUMBER,
		Default = 18,
	},
	["ZombieNumberPlayerScale"] = {
		Type = TYPE_NUMBER,
		Default = 6,
	},

	["ZombieHealthScaleLinear"] = {
		Type = TYPE_NUMBER,
		Default = 100,
	},
	["ZombieHealthScalePower"] = {
		Type = TYPE_NUMBER,
		Default = 1.1,
	},
	["ZombieHealthBase"] = {
		Type = TYPE_NUMBER,
		Default = 50,
	},
}

if CLIENT then
	local panelfunc = function(self, sp)
		local zh = self:Add("Panel")
		local zh_l = self:Add("DLabel")
		zh_l:SetText("Zombie Health Curves")
		zh_l:Dock(TOP)
		zh_l:SetTall(50)
		zh_l:SetFont("DermaLarge")

		local zh_b = zh:Add("Panel")
		local zh_bl = zh_b:Add("DLabel")
		zh_bl:Dock(LEFT)
		zh_bl:SetText("Base health")
		local zh_bp = sp("ZombieHealthBase", zh_b)
		zh_bp:Dock(FILL)
		zh_b:Dock(TOP)
		zh_b:SetTall(20)

		local zh_rs = zh:Add("Panel")
		local zh_rsl = zh_rs:Add("DLabel")
		zh_rsl:Dock(LEFT)
		zh_rsl:SetText("Add up to R10")
		local zh_rsl = sp("ZombieHealthScaleLinear", zh_rs)
		zh_rsl:Dock(FILL)
		zh_rs:Dock(TOP)
		zh_rs:SetTall(20)

		local zh_ps = zh:Add("Panel")
		local zh_psl = zh_ps:Add("DLabel")
		zh_psl:Dock(LEFT)
		zh_psl:SetText("Scale after R10")
		local zh_psl = sp("ZombieHealthScalePower", zh_ps)
		zh_psl:Dock(FILL)
		zh_ps:Dock(TOP)
		zh_ps:SetTall(20)

		local za_l = self:Add("DLabel")
		za_l:SetText("Zombie Number Curves")
		za_l:Dock(TOP)
		za_l:SetTall(50)
		za_l:SetFont("DermaLarge")

		local za_b = zh:Add("Panel")
		local za_bl = za_b:Add("DLabel")
		za_bl:Dock(LEFT)
		za_bl:SetText("Base amount")
		local za_bp = sp("ZombieNumberBase", za_b)
		za_bp:Dock(FILL)
		za_b:Dock(TOP)
		za_b:SetTall(20)

		local za_rs = zh:Add("Panel")
		local za_rsl = za_rs:Add("DLabel")
		za_rsl:Dock(LEFT)
		za_rsl:SetText("Round scale")
		local za_rsl = sp("ZombieNumberRoundScale", za_rs)
		za_rsl:Dock(FILL)
		za_rs:Dock(TOP)
		za_rs:SetTall(20)

		local za_ps = zh:Add("Panel")
		local za_psl = za_ps:Add("DLabel")
		za_psl:Dock(LEFT)
		za_psl:SetText("Player scale")
		local za_psl = sp("ZombieNumberPlayerScale", za_ps)
		za_psl:Dock(FILL)
		za_ps:Dock(TOP)
		za_ps:SetTall(20)

		self:SetTall(400)
	end

	return settings, panelfunc
end

return settings