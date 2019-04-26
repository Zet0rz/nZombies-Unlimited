include( "shared.lua" )

local hidden = {
	CHudHealth = true,
	CHudBattery = true,
	CHudAmmo = true,
	CHudSecondaryAmmo = true,
	CHudWeaponSelection = true,
}
function GM:HUDShouldDraw(name)
	if hidden[name] then return false end
	return true
end