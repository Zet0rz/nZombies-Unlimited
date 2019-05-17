local EXTENSION = nzu.Extension()

local settings = {
	["EnabledPowerups"] = {
		Default = {}, -- Default is empty = use all powerups
		NetRead = function()
			local t = {}
			local num = net.ReadUInt(8)
			for i = 1,num do
				local class = net.ReadString()
				t[class] = net.ReadBool()
			end
			return t
		end,
		NetWrite = function(t)
			local t2 = table.GetKeys(t)
			local num = #t2
			net.WriteUInt(num, 8)
			for i = 1,num do
				local class = t2[i]
				net.WriteString(class)
				net.WriteBool(t[class])
			end
		end,
		Panel = function(parent, ext)
			
		end
	},
}

if CLIENT then
	local panelfunc = function(p, SettingPanel)
		
	end
	return settings, panelfunc
end

return settings