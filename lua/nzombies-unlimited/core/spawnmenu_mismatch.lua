list.Set("DesktopWindows", "nzu_Mismatch", {
	title = "[NZU] Mismatch",
	icon = "icon64/tool.png",
	width = 400,
	height = 500,
	onewindow = true,
	init = function(icon, window)
		window:SetSkin("nZombies Unlimited")

		if nzu.IsAdmin(LocalPlayer()) then
			local top = window:Add("Panel")
			top:SetTall(30)
			top:Dock(TOP)
			top:DockPadding(5,5,5,5)

			local refresh = top:Add("DButton")
			refresh:SetWide(185)
			refresh:Dock(RIGHT)
			refresh:SetText("Request Server re-check")
			refresh.DoClick = function()
				nzu.RequestMismatch()
			end

			local request = top:Add("DButton")
			request:SetWide(185)
			request:Dock(LEFT)
			request:SetText("No available data...")
			request:SetEnabled(false)
			request.DoClick = function()
				nzu.RequestMismatchData()
			end

			-- Easy?
			local mismatch = window:Add("nzu_MismatchPanel")
			mismatch:Dock(FILL)

			-- Let's add some hooks to nicely enable/disable the request button
			local function updaterequest()
				local num = 0
				for k,v in pairs(nzu.GetAvailableMismatches()) do
					if not nzu.GetReceivedMismatchData(v) then
						num = num + 1
					end
				end
				if num > 0 then
					request:SetText("Request Data ("..num..")")
					request:SetEnabled(true)
				else
					request:SetText("No available data...")
					request:SetEnabled(false)
				end
			end

			mismatch.OnMismatchAdded = updaterequest
			mismatch.OnMismatchClosed = updaterequest

			updaterequest()
		else
			window:Remove()
			notification.AddLegacy("Only Admins may access Mismatch.", NOTIFY_ERROR, 5)
		end
	end
})

hook.Add("nzu_MismatchFound", "nzu_Mismatch_Notify", function(key)
	notification.AddLegacy("Mismatch found: "..key.."! Access through Context Menu.", NOTIFY_GENERIC, 10)
end)