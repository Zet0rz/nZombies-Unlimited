
-- String: A text entry that will send whenever it loses focus
nzu.AddExtensionSettingType("String", {
	NetRead = net.ReadString,
	NetWrite = net.WriteString,
	Panel = {
		Create = function(parent)
			local p = vgui.Create("DTextEntry", parent)
			p:SetTall(40)

			function p:OnFocusChanged(b)
				if not b then p:Send() end -- Trigger networking on text field focus lost
			end

			return p
		end,
		Set = function(p,v) p:SetText(v or "") end,
		Get = function(p) return p:GetText() end
	}
})

-- Number: A networked double with a Number Wang
nzu.AddExtensionSettingType("Number", {
	NetRead = net.ReadDouble,
	NetWrite = net.WriteDouble,
	Panel = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)
			p.N = p:Add("DNumberWang")
			p.N:Dock(FILL)
			p.N:SetMinMax(nil,nil)
			p:SetTall(40)

			function p.N.OnValueChanged()
				if p.Send then p:Send() end -- Trigger networking whenever it changes
			end

			return p
		end,
		Set = function(p,v) p.N:SetValue(v) end,
		Get = function(p) return p.N:GetValue() end
	}
})

-- Boolean: A true/false value that appears as a checkbox, networked whenever clicked
nzu.AddExtensionSettingType("Boolean", {
	NetRead = net.ReadBool,
	NetWrite = net.WriteBool,
	Panel = {
		Create = function(parent)
			local p = vgui.Create("DTextEntry", parent)
			p:SetTall(40)

			function p:OnFocusChanged(b)
				if not b then p:Send() end -- Trigger networking on text field focus lost
			end

			return p
		end,
		Set = function(p,v) p:SetText(v or "") end,
		Get = function(p) return p:GetText() end
	}
})

-- Vector: 3 number wangs with an associated Save button. Uses DVectorEntry (included in nZU)
nzu.AddExtensionSettingType("Vector", {
	NetRead = net.ReadVector,
	NetWrite = net.WriteVector,
	Panel = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)

			p.S = p:Add("DButton")
			p.S:SetText("Save")
			p.S:Dock(RIGHT)
			p.S:SetWide(50)

			p.V = p:Add("DVectorEntry")
			p.V:Dock(FILL)

			p:SetSize(200,20)

			p.S.DoClick = function() p:Send() end -- Network on button click

			return p
		end,
		Set = function(p,v) p.V:SetVector(v) end,
		Get = function(p) return p.V:GetVector() end
	}
})

-- Angle: 3 number wangs with an associated Save button, similar to Vector
nzu.AddExtensionSettingType("Angle", {
	NetRead = net.ReadAngle,
	NetWrite = net.WriteAngle,
	Panel = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)

			p.S = p:Add("DButton")
			p.S:SetText("Save")
			p.S:Dock(RIGHT)
			p.S:SetWide(50)

			p.A = p:Add("DAngleEntry")
			p.A:Dock(FILL)

			p:SetSize(200,20)

			p.S.DoClick = function() p:Send() end -- Network on button click

			return p
		end,
		Set = function(p,v) p.A:SetAngles(v) end,
		Get = function(p) return p.A:GetAngles() end
	}
})

-- Matrix: 4x4 number wangs with an associated Save button, also similar to Angle and Vector
nzu.AddExtensionSettingType("Matrix", {
	NetRead = net.ReadMatrix,
	NetWrite = net.WriteMatrix,
	Panel = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)

			p.S = p:Add("DButton")
			p.S:SetText("Save")
			p.S:Dock(BOTTOM)
			p.S:SetTall(20)

			p.M = p:Add("DMatrixEntry")
			p.M:Dock(FILL)

			p:SetSize(200,100)

			p.S.DoClick = function() p:Send() end -- Network on button click

			return p
		end,
		Set = function(p,v) p.M:SetMatrix(v) end,
		Get = function(p) return p.M:GetMatrix() end
	}
})

-- Color: A color select with a Save button
nzu.AddExtensionSettingType("Color", {
	NetRead = net.ReadColor,
	NetWrite = net.WriteColor,
	Load = function(t) return IsColor(t) and t or Color(t.r, t.g, t.b, t.a) end,
	Panel = {
		Create = function(parent)
			local p = vgui.Create("Panel", parent)

			p.S = p:Add("DButton")
			p.S:SetText("Save")
			p.S:Dock(BOTTOM)
			p.S:SetTall(20)

			p.C = p:Add("DColorMixer")
			p.C:Dock(FILL)

			p:SetSize(200,185)

			p.S.DoClick = function() p:Send() end -- Network on button click

			return p
		end,
		Set = function(p,v) p.C:SetColor(v) end,
		Get = function(p) local c = p.C:GetColor() return Color(c.r,c.g,c.b,c.a) end
	}
})

-- Weapon: A text field dropdown that contains all installed weapons, including a search field to filter the dropdown
nzu.AddExtensionSettingType("Weapon", {
	NetWrite = net.WriteString,
	NetRead = net.ReadString,
	Panel = {
		Create = function(parent, ext, setting)
			local p = vgui.Create("DSearchComboBox", parent)

			p:AddChoice("  [None]", "") -- Allow the choice of none
			for k,v in pairs(weapons.GetList()) do
				p:AddChoice((v.PrintName or "").." ["..v.ClassName.."]", v.ClassName)
			end
			p:SetAllowCustomInput(true)

			function p:OnSelect(index, value, data)
				self:Send()
			end

			return p
		end,
		Set = function(p,v)
			for k,class in pairs(p.Data) do
				if class == v then
					p:SetText(p:GetOptionText(k))
					p.selected = k
					return
				end
			end

			p.Choices[0] = v
			p.Data[0] = v
			p.selected = 0
			p:SetText(v)
		end,
		Get = function(p)
			local str,data = p:GetSelected()
			return data
		end,
	}
})

-- Option Set: A dropdown containing a selection of options networked from the Server.
-- Note: This setting requires implementing GetOptions which should return a table of pairs: {Option = data, Display = pretty}
-- where 'data' is the value networked, and 'pretty' is a pretty display name for the dropdown. If pretty doesn't exist, data is used in its place.
local optionset = {
	NetWrite = net.WriteString,
	NetRead = net.ReadString,
	GetOptions = function()
		return {} -- Nothing by default! You must implement this if you want any options!
	end,
}
if SERVER then
	util.AddNetworkString("nzu_optionset")
	local function networkoptions(ext, s, ply)
		if type(ext) == "string" then ext = nzu.GetExtension(ext) end
		if ext then
			local setting = ext:GetSettingsMeta()[s]
			if setting and setting.GetOptions then
				local tbl = setting.GetOptions()
				local num = #tbl

				if num > 0 then
					net.Start("nzu_optionset")
						net.WriteString(k)
						net.WriteUInt(num, 16)
						for i = 1,num do
							net.WriteString(tbl[i].Option)
							net.WriteString(tbl[i].Display)
						end
					net.Send(ply)
				end
			end
		end
	end

	-- In Sandbox, cache all option sets created and network them to any player joining
	if NZU_SANDBOX then
		local sets = {}
		optionset.Create = function(ext, setting)
			sets[setting] = ext
		end

		hook.Add("PlayerInitialSpawn", "nzu_Extensions_OptionSetNetwork", function(ply)
			for k,v in pairs(sets) do
				networkoptions(v, k, ply)
			end
		end)
	else
		-- In nZombies, only respond to admin requests
		net.Receive("nzu_optionset", function(len, ply)
			if nzu.IsAdmin(ply) then
				local ext = net.ReadString()
				local id = net.ReadString()

				networkoptions(ext, id, ply)
			end
		end)
	end
else
	local function readoptions()
		local id = net.ReadString()
		local num = net.ReadUInt(16)

		local tbl = {}
		for i = 1,num do
			local t = {}
			t.Option = net.ReadString()
			t.Display = net.ReadString()

			table.insert(tbl, t)
		end

		return id, tbl
	end

	local sets
	if NZU_SANDBOX then
		sets = {}
	end

	net.Receive("nzu_optionset", function()
		local id,tbl = readoptions()
		if sets then sets[id] = tbl end -- Only do this in Sandbox pretty much

		hook.Run("nzu_OptionSetUpdated", id, tbl)
	end)

	optionset.Panel = {
		Create = function(parent, ext, setting)
			local p = vgui.Create("DComboBox", parent)

			function p:Populate(id, tbl)
				if id == setting then
					self:Clear()
					for k,v in pairs(tbl) do
						self:AddChoice(v.Display, v.Option)
					end
				end
			end

			if NZU_SANDBOX then
				if sets and sets[setting] then
					p:Populate(setting, sets[setting])
				end
			else
				-- Request options
				net.Start("nzu_optionset")
					net.WriteString(ext.ID)
					net.WriteString(setting)
				net.SendToServer()
			end
			hook.Add("nzu_OptionSetUpdated", p, p.Populate)

			function p:OnSelect(index, value, data)
				self:Send()
			end
			return p
		end,
		Set = function(p,v)
			for k,data in pairs(p.Data) do
				if data == v then
					p:SetText(p:GetOptionText(k))
					p.selected = k
					return
				end
			end

			p.Choices[0] = v
			p.Data[0] = v
			p.selected = 0
			p:SetText(v)
		end,
		Get = function(p)
			local str,data = p:GetSelected()
			return data
		end,
	}
end
nzu.AddExtensionSettingType("OptionSet", optionset)