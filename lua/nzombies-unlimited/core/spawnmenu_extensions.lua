
local function generateextensionpanel(id, ext)
	local f = vgui.Create("DCollapsibleCategory")
	f:SetLabel((ext.Details.Name or "[Unknown Name]") .. " ["..id.."]")

	local checkbox = f.Header:Add("DCheckBoxLabel")
	checkbox:Dock(RIGHT)
	checkbox:SetWide(20)

	if ext.Loaded then
		checkbox:SetChecked(true)
		local extension = nzu.GetExtension(id)
		local panel
		if extension and extension.Panel then panel = extension:Panel() else
			panel = vgui.Create("DLabel")
			panel:SetText("No control panel for this Extension.")
		end
		f:SetContents(panel)
	end

	checkbox.OnChange = function(s,b)
		net.Start("nzu_extension_load")
			net.WriteString(id)
			net.WriteBool(b)
		net.SendToServer()
	end

	return f
end

local columns = 3
local pad = 3
nzu.AddSpawnmenuTab("Config Settings", "DPanel", function(panel)
	panel.Lists = {}
	for i = 1,columns do
		local p = panel:Add("DScrollPanel")
		p:Dock(LEFT)
		p:DockMargin(pad,2,0,2)

		panel.Lists[i] = p
	end

	function panel:PerformLayout()
		local w = (self:GetWide() - pad)/columns - pad
		for i = 1,columns do
			panel.Lists[i]:SetWide(w)
		end
	end

	nzu.RefreshExtensions()
	local loadedexts = 1
	for i = 1,6 do
		for k,v in pairs(nzu.GetExtensionList()) do
			local f = generateextensionpanel(k,v)
			panel.Lists[loadedexts]:Add(f)
			f:Dock(TOP)
			f:SetHeight(300)

			loadedexts = loadedexts < columns and loadedexts + 1 or 1
		end
	end
end, "icon16/plugin.png", "Control Config Settings and Extensions")