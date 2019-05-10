
--[[-------------------------------------------------------------------------
Resource Sets
A table that gets populated with content from a text (lua) file
Can be included as an Extension Setting to be automatically networked
Can be chosen to be networked to clients or not - using nzu.ClientResourceSet or with Client field in Extension Settings
---------------------------------------------------------------------------]]

local resourcesetpath = "nzombies-unlimited/resourcesets/"

local customtype = {
	NetWrite = net.WriteString,
	NetRead = net.ReadString,
}

local function sendresource(tbl)
	net.WriteTable(tbl) -- This is inefficient, but we want to ensure resource sets can have structures such as sub-tables

	--[[local num = #tbl
	net.WriteUInt(num, 16)
	for i = 1,num do
		net.WriteString(tbl[i])
	end]]
end

local function readresource()
	local tbl = net.ReadTable()

	--[[local num = net.ReadUInt(16)
	local tbl = {}
	for i = 1,num do
		tbl[i] = net.ReadString()
	end]]
	return tbl
end

if NZU_NZOMBIES then
	local selectedsets = {}
	function nzu.GetResourceSet(id)
		local id = string.lower(id)
		if not selectedsets[id] then
			selectedsets[id] = {} -- Kinda works like a pre-cache
		end
		return selectedsets[id]
	end

	local function doselect(id, tbl)
		local t = selectedsets[id]
		if t then
			local notify = t.OnChange
			table.Empty(t)
			for k,v in pairs(tbl) do
				t[k] = v -- We merge it into the existing table so that any code references will now also contain the new values
			end
			t.OnChange = notify
		else
			selectedsets[id] = tbl
			t = tbl
		end

		if t.OnChange then t.OnChange() end
		hook.Run("nzu_ResourceSetUpdated", id, t)
	end

	if SERVER then
		local networks = {}
		function nzu.ClientResourceSet(id)
			local id = string.lower(id)
			networks[id] = true
		end

		util.AddNetworkString("nzu_resourceset")
		local function networkresourceset(id, tbl, ply)
			net.Start("nzu_resourceset")
				net.WriteString(id)
				sendresource(tbl)
			if ply then net.Send(ply) else net.Broadcast() end
		end

		local function readset(id, set)
			if not set or set == "none" or set == "" then return {} end

			local tbl
			if type(set) == "table" then tbl = set else
				local data = file.Read(resourcesetpath..id.."/"..set..".txt", "DATA")
				if not data then data = file.Read(resourcesetpath..id.."/"..set..".lua", "LUA") end

				if data then
					tbl = util.JSONToTable(data)
				end
			end
			if tbl.Base then
				local base = readset(id, tbl.Base) -- Could either be a string, or another table - it's recursive too (Please don't cause infinite loops!)
				if base and base.Set then
					for k,v in pairs(base.Set) do
						if tbl.Set[k] == nil then tbl.Set[k] = v end
					end
				end
			end
			return tbl
		end

		function nzu.SelectResourceSet(id, set)
			local id = string.lower(id)
			local set = string.lower(set)
			local tbl = readset(id, set)

			if not tbl or not tbl.Set then return end
			doselect(id, tbl.Set)

			if networks[id] then
				networkresourceset(id, tbl.Set)
			end
		end

		hook.Add("PlayerInitialSpawn", "nzu_ResourceSet_Network", function(ply)
			for k,v in pairs(networks) do
				if selectedsets[k] then
					networkresourceset(k, selectedsets[k], ply)
				end
			end
		end)

		-- Setting features
		customtype.Create = function(ext, setting, tbl)
			if tbl.Client then
				nzu.ClientResourceSet(setting)
			end
		end

		-- Make it select the set when changed!
		customtype.Notify = function(v,k)
			nzu.SelectResourceSet(k,v)
		end
	else
		net.Receive("nzu_resourceset", function()
			local id = net.ReadString()
			doselect(id, readresource())
		end)
	end
end

-- Option available files so that clients can display them in the dropdown
if SERVER then
	util.AddNetworkString("nzu_resourceset_options")

	local function networkoptions(id, ply)
		local files,_ = file.Find(resourcesetpath..id.."/*.txt", "DATA")
		local f2,_ = file.Find(resourcesetpath..id.."/*.lua", "LUA")
		
		local tbl = {}
		local found = {}
		for k,v in pairs(files) do
			local data = file.Read(resourcesetpath..id.."/"..v, "DATA")
			local json = util.JSONToTable(data)
			if json and json.Name and json.Set then
				local id2 = string.StripExtension(v)
				table.insert(tbl, {id2, json.Name})
				found[id2] = true
			end
		end

		for k,v in pairs(f2) do
			local id2 = string.StripExtension(v)
			if not found[id2] then
				local data = file.Read(resourcesetpath..id.."/"..v, "LUA")
				local json = util.JSONToTable(data)
				if json and json.Name and json.Set then
					table.insert(tbl, {id2, json.Name})
				end
			end
		end

		local num = #tbl
		if num > 0 then
			net.Start("nzu_resourceset_options")
				net.WriteString(id)

				net.WriteUInt(num, 16)
				for i = 1,num do
					local v = tbl[i]
					net.WriteString(v[1])
					net.WriteString(v[2])
				end
			net.Send(ply)
		end
	end

	if NZU_NZOMBIES then
		net.Receive("nzu_resourceset_options", function(len, ply)
			if nzu.IsAdmin(ply) then
				local id = net.ReadString()
				networkoptions(id, ply)
			end
		end)
	else
		hook.Add("PlayerInitialSpawn", "nzu_ResourceSet_NetworkOptions", function(ply)
			local dir = resourcesetpath.."*"
			local f,dirs = file.Find(dir, "DATA")
			local _,d2 = file.Find(dir, "LUA")

			local done = {}
			for k,v in pairs(dirs) do
				networkoptions(v, ply)
				done[v] = true
			end

			for k,v in pairs(d2) do
				if not done[v] then networkoptions(v, ply) end
			end
		end)
	end

	-- Receiving the request to create a new set
	--[[net.Receive("nzu_resourceset", function(len, ply)
		if nzu.IsAdmin(ply) then
			local id = net.ReadString()
			local set = net.ReadString()
			local base = net.ReadString()
			if base == "" then base = nil end

			local tbl = readresource()

			file.Write(resourcesetpath..id.."/"..set..".txt", util.TableToJSON({Name = set, Base = base, Set = tbl}, true))
			networkoptions(id, NZU_SANDBOX and player.GetAll() or ply) -- Update the list for all players if sandbox, otherwise just for the player who saved this
		end
	end)]]
else
	local resourceoptions = {}
	net.Receive("nzu_resourceset_options", function()
		local id = net.ReadString()
		local num = net.ReadUInt(16)

		local tbl = {}
		for i = 1,num do
			local f = net.ReadString()
			local n = net.ReadString()
			tbl[i] = {f,n}
		end

		resourceoptions[id] = tbl
		hook.Run("nzu_ResourceSetOptionsUpdated", id, tbl)
	end)

	local function populateoptions(p,id)
		local id = string.lower(id)
		if p.Setting ~= id then return end
		p:Clear()
		p:AddChoice("None", "")

		if resourceoptions[id] then
			for k,v in pairs(resourceoptions[id]) do
				p:AddChoice(v[2], v[1])
			end
		end

		--if nzu.IsAdmin(LocalPlayer()) then p:AddChoice("Create new set ...") end
	end

	--[[local folders = {
		{Base = "sound", Name = "Sounds", Icon = "icon16/music.png", Filter = "*.wav *.mp3 *.ogg", Default = "nzu"},
		{Base = "models", Name = "Models", Icon = "icon16/user.png", Filter = "*.mdl", Models = true, Default = "nzu"},
		{Base = "materials", Name = "Materials", Icon = "icon16/chart_pie.png", Filter = "*.vmt *.png *.jpg", Default = "nzombies-unlimited"},
	}

	local function setcreator(set)
		local frame = vgui.Create("DFrame")
		frame:SetTitle("Creating new "..set.." Resource Set")
		frame:SetDeleteOnClose(true)
		frame:ShowCloseButton(true)
		frame:SetSize(400,600)

		local sheet = frame:Add("DPropertySheet")
		sheet:Dock(FILL)

		for k,v in pairs(folders) do
			local browser = vgui.Create("DFileBrowser", sheet)
			browser:SetPath("GAME")
			browser:SetBaseFolder(v.Base)
			browser:SetFileTypes(v.Filter)
			--browser:SetCurrentFolder(v.Default)
			--browser:SetModels(v.Models)
			browser:SetOpen(true)
			browser:Dock(FILL)

			function browser:OnSelect(path)
				self.SelectedPath = path
			end
			function browser:GetText()
				return self.SelectedPath
			end

			sheet:AddSheet(v.Name, browser, v.Icon)
		end

		local txt = vgui.Create("DTextEntry", sheet)
		txt:Dock(BOTTOM)
		txt:SetTall(30)
		sheet:AddSheet("Strings", txt, "icon16/comment_edit.png")

		local scroll = frame:Add("DScrollPanel")
		scroll:Dock(TOP)
		scroll:SetTall(300)
		scroll:SetPaintBackground(true)

		local add = frame:Add("DButton")
		add:SetText("Add Selected")
		add:Dock(BOTTOM)
		add:SetTall(25)
		add.DoClick = function()
			local pnl = sheet:GetActiveTab():GetPanel()
			local val = pnl:GetText()

			if val then
				local lbl = scroll:Add("DLabel")
				lbl:SetText(val)
				lbl:Dock(TOP)
				lbl:SetDark(true)

				local rem = lbl:Add("DImageButton")
				rem:SetImage("icon16/cancel.png")
				rem:Dock(RIGHT)
				rem:SetWide(16)
			end

			print(pnl:GetText())
		end

		frame:Center()
		frame:MakePopup()
		frame:DoModal(true)
	end
	nzu.SetCreator = setcreator -- DEBUG]]

	customtype.Panel = {
		Create = function(parent, ext, setting)
			local p = vgui.Create("DComboBox", parent)
			function p:OnSelect(index, value, data)
				if value == "Create new set ..." then
					--setcreator(setting, ext)
				else
					self:Send(data or value)
				end
			end

			p.Setting = setting
			populateoptions(p,setting)
			hook.Add("nzu_ResourceSetOptionsUpdated", p, populateoptions)

			-- Request options if the panel was created in nZombies
			-- It'll update itself with the hook right above (if we receive any)
			if NZU_NZOMBIES then
				net.Start("nzu_resourceset_options")
					net.WriteString(string.lower(setting))
				net.SendToServer()
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
			return p:GetSelected()
		end,
	}
end

nzu.AddExtensionSettingType("ResourceSet", customtype)