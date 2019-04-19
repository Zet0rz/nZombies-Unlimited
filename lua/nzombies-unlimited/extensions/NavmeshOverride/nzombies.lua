
if SERVER then
	local function loadnavmeshtable(tbl)
		navmesh.Reset()
		local areas = {}
		for k,v in ipairs(tbl) do
			local area = navmesh.CreateNavArea(Vector(), Vector())
			for i = 0, 3 do
				area:SetCorner(i, v.Corners[i])
			end
			area:SetAttributes(v.Attributes)
			areas[k] = area
		end
		
		-- Create connections
		for k,v in ipairs(tbl) do
			local area = areas[k]
			if v.Connections then
				for k2,v2 in pairs(v.Connections) do
					area:ConnectTo(areas[v2])
				end
			end
			if v.Parent then
				area:SetParent(areas[v.Parent])
			end
		end
	end

	-- Let's load the saved file if it exists
	nzu.AddSaveExtension("NavmeshReplace", {
		PreLoad = function()
			local str = nzu.ReadConfigFile("navmesh.txt")
			if str then
				loadnavmeshtable(util.JSONToTable(str))
			end
		end
	})
end