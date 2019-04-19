
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

	local function savenavmeshtable()
		local tbl = {}
		for k,v in ipairs(navmesh.GetAllNavAreas()) do
			local t = {}
			t.Attributes = v:GetAttributes()
			
			t.Corners = {}
			for i = 0, 3 do
				t.Corners[i] = v:GetCorner(i)
			end
			
			local connections = v:GetAdjacentAreas()
			if connections and table.Count(connections) > 0 then
				t.Connections = {}
				for k2,v2 in pairs(connections) do
					table.insert(t.Connections, v2:GetID())
				end
			end
			if v:GetParent() then t.Parent = v:GetParent():GetID() end
			
			tbl[k] = t
		end
		return tbl
	end

	-- Let's load the saved file if it exists
	nzu.AddSaveExtension("NavmeshReplace", {
		PreSave = function()
			nzu.WriteConfigFile("navmesh.txt", util.TableToJSON(savenavmeshtable()))
		end,
		PreLoad = function()
			local str = nzu.ReadConfigFile("navmesh.txt")
			if str then
				loadnavmeshtable(util.JSONToTable(str))
			end
		end
	})
end