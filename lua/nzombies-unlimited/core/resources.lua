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
	CustomPanel = {
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
	NetSend = net.WriteString,
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

	local hookedsets = {}
	customtype.Create = function(ext, setting)
		nzu.RegisterResourceSet(setting)
		hookedsets[ext.ID] = true
	end

	hook.Add("nzu_ExtensionSettingChanged", "nzu_Resources_AutoSettingChangeSet", function(id, k, v)
		if hookedsets[id] and nzu.GetExtension(id).GetSettingsMeta()[k].Type == "ResourceSet" then
			nzu.SelectResourceSet(k,v)
		end
	end)

	hook.Add("nzu_ExtensionLoaded", "nzu_Resources_AutoSettingLoad", function(name)
		if hookedsets[name] then
			local ext = nzu.GetExtension(name)
			for k,v in pairs(ext.GetSettingsMeta()) do
				if v.Type == "ResourceSet" then
					nzu.SelectResourceSet(k,ext.Settings[k])
				end
			end
		end
	end)

	function nzu.GetResources(set)
		return selected[set]
	end
end

nzu.AddCustomExtensionSettingType("ResourceSet", customtype)
--[[-------------------------------------------------------------------------
Sound play networking
---------------------------------------------------------------------------]]
if SERVER then
	util.AddNetworkString("nzu_sound") -- Server: Broadcast a sound filepath to play on clients

	function nzu.PlayClientSound(path, recipients)
		net.Start("nzu_sound")
			net.WriteString(path)
		if recipients then net.Send(recipients) else net.Broadcast() end
	end
else
	net.Receive("nzu_sound", function()
		surface.PlaySound(net.ReadString())
	end)
end