--[[-------------------------------------------------------------------------
Resource System
---------------------------------------------------------------------------]]
local resources = {}
function nzu.GetResourceSetList(set)
	return table.GetKeys(resources[set])
end

local function setresourceset(p,set)
	for k,v in pairs(nzu.GetResourceSetList(set)) do
		p:AddChoice(v)
	end
end

local customtype = {
	Panel = {
		Create = function(parent, ext, setting)
			local p = vgui.Create("DComboBox", parent)
			function p:OnSelect(index, value)
				self:Send()
			end

			if resources[setting] then
				setresourceset(p,setting)
			end

			return p
		end,
		Set = function(p,v)
			p:SetValue(v)
		end,
		Get = function(p)
			return p:GetSelected()
		end,
	},
	NetWrite = net.WriteString,
	NetRead = net.ReadString,
}

if NZU_SANDBOX then
	function nzu.RegisterResourceSet(set)
		resources[set] = resources[set] or {}
	end

	local exts = {}
	function nzu.AddResourceSet(set, id)
		resources[set][id] = true -- Sandbox doesn't really care about what it actually is, only that it exists
		if CLIENT and exts[set] then
			exts[set]:RebuildPanels()
		end
	end

	-- Sandbox: Create dropdown menu containing all added options
	-- Data type: String
	customtype.Create = function(ext, setting)
		nzu.RegisterResourceSet(setting)
		exts[setting] = ext
	end
end

if NZU_NZOMBIES then
	local selected = {}
	function nzu.RegisterResourceSet(set)
		resources[set] = resources[set] or {}
		selected[set] = {}
	end

	local queue = {}
	function nzu.AddResourceSet(set, id, tbl)
		resources[set][id] = tbl
		if queue[set] == id then
			nzu.SelectResourceSet(set, id)
		end
	end

	function nzu.SelectResourceSet(set, id)
		local tbl = selected[set]
		if tbl then
			table.Empty(tbl)
		else
			tbl = {}
			selected[set] = tbl
		end

		if resources[set] and resources[set][id] then
			for k,v in pairs(resources[set][id]) do
				tbl[k] = v
			end
			queue[set] = nil
		else
			queue[set] = id
		end
	end

	customtype.Create = function(ext, setting)
		nzu.RegisterResourceSet(setting)
	end
	customtype.Notify = function(v,k)
		nzu.SelectResourceSet(k,v)
	end

	function nzu.GetResources(set)
		return selected[set]
	end
end

nzu.AddExtensionSettingType("ResourceSet", customtype)
