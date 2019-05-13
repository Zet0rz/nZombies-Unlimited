local EXTENSION = nzu.Extension()

local settings = {
	--[[["WeaponList"] = {
		Default = {},

	},]]
}

if CLIENT then
	local panelfunc = function(p, SettingPanel)
		
		return p
	end
	return settings, panelfunc
end

return settings