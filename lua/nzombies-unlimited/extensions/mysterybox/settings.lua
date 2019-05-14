local EXTENSION = nzu.Extension()

local settings = {
	["WeaponList"] = {
		Default = {}, -- Default is empty = use all installed weapons (that are valid)
		NetRead = function()
			local t = {}
			local num = net.ReadUInt(16)
			for i = 1,num do
				local class = net.ReadString()
				t[class] = net.ReadUInt(16)
			end
			return t
		end,
		NetWrite = function(t)
			local t2 = table.GetKeys(t)
			local num = #t2
			net.WriteUInt(num, 16)
			for i = 1,num do
				local class = t2[i]
				net.WriteString(class)
				net.WriteUInt(t[class], 16)
			end
		end,
		Panel = function(parent, ext)
			
		end
	},
}

if CLIENT then
	local panelfunc = function(p, SettingPanel)
		
		return p
	end
	return settings, panelfunc
end

return settings