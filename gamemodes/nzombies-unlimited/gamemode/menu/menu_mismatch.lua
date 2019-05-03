
-- Make a button that opens the Mismatch panel
-- But update the button so that it only appears when there is something to mismatch,
-- as well as how many categories we have available
hook.Add("nzu_MenuCreated", "Mismatch", function(menu)
	local sub,but = menu:AddSubMenu("Config Mismatch", 100, nil, true)
	local mismatch = vgui.Create("nzu_MismatchPanel", sub)
	sub:SetContents(mismatch) -- Kind of reversved order, but still works

	local function updaterequest()
		local num = #nzu.GetAvailableMismatches()
		if num > 0 then
			but:SetText("Config Mismatch! ("..num..")")
			but:SetVisible(true)
		else
			but:SetVisible(false)
		end
	end

	function sub:OnShown()
		nzu.RequestMismatchData()
	end

	sub.OnHid = updaterequest
	mismatch.OnMismatchAdded = updaterequest
	mismatch.OnMismatchClosed = updaterequest

	but:SetVisible(false)
end)