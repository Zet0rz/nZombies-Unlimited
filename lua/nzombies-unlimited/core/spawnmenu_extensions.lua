
local function generatesettingspanel(ext)
	local p = nzu.GetExtensionPanel(ext)
	if not p then
		p = vgui.Create("DPanel")
		local t = p:Add("DLabel")
		t:SetText("No settings for this extension...")
		t:SetContentAlignment(5)
		t:SetTextColor(Color(0,0,0))
		t:Dock(TOP)
		p:SetTall(30)
	end
	return p
end

local function generateextensionpanel(ext)
	local f = vgui.Create("DCollapsibleCategory")
	local details = nzu.GetExtensionDetails(ext)

	f:SetLabel((details.Name or "[Unknown Name]") .. " ["..ext.."]")

	local checkbox = f.Header:Add("DCheckBoxLabel")
	checkbox:Dock(RIGHT)
	checkbox:SetWide(20)
	checkbox:SetChecked(nzu.IsExtensionLoaded(ext))
	f.LoadedCheckbox = checkbox
	f:SetContents(generatesettingspanel(""))

	checkbox.OnChange = function(s,b)
		net.Start("nzu_extension_load")
			net.WriteString(ext)
			net.WriteBool(b)
		net.SendToServer()
	end

	return f
end

local extpanels = {}

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

	local loadedexts = 1
	for i = 1,6 do
		for k,v in pairs(nzu.GetInstalledExtensionList()) do
			local f = generateextensionpanel(v)
			panel.Lists[loadedexts]:Add(f)
			f:Dock(TOP)
			f:SetHeight(300)

			loadedexts = loadedexts < columns and loadedexts + 1 or 1
			extpanels[v] = f
		end
	end
end, "icon16/plugin.png", "Control Config Settings and Extensions")

hook.Add("nzu_ExtensionLoaded", "nzu_SpawnmenuExtension", function(ext)
	local pnl = extpanels[ext]
	if pnl then
		--[[local p = vgui.Create("DPanel")
		p:SetBackgroundColor(Color(0,255,0))
		p:SetSize(100,500)

		extpanels[ext]:SetContents(p)]]

		pnl.LoadedCheckbox:SetChecked(true)
		local p = generatesettingspanel(ext)
		timer.Simple(0, function()
			if pnl:GetExpanded() then
				pnl:SetTall(p:GetTall() + pnl.Header:GetTall())
			else
				pnl.OldHeight = p:GetTall() + pnl.Header:GetTall()
				pnl:DoExpansion(true)
			end
			pnl:SetContents(p)
		end)
	end
end)

hook.Add("nzu_ExtensionSettingChanged", "nzu_SpawnmenuExtension", function(ext, setting, value)
	local pnl = extpanels[ext]
	if pnl and pnl.Contents.SettingPanels and pnl.Contents.SettingPanels[setting] then
		pnl.Contents.SettingPanels[setting]:_SetValue(value)
	end
end)