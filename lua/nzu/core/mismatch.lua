--[[ Mismatch Systems 
	If your extension contains a "mismatch.lua" file, this file is executed when the config is loaded, in order to attempt to find any issues with the settings or entities etc.
	In this file, you should do nothing but return a table containing your mismatched data. Your table should have the following structure:

	=== Collect: function() --> returns data [SERVER]
	A function with no arguments, that should return any data for your subsequent functions. This data is cached after it is collected once.
	Return nil when there is nothing mismatching. An empty table will count as non-nil, and will trigger the system.

	=== Write: function(data) --> returns nil
	A function taking the above data as argument, that should network the data. Note that this happens on BOTH Server and Client: Servers to send the data to a client for the panel, and Clients networking back the changes they wish to do
	Feel free to use "if SERVER/CLIENT" to separate the ways it does this.

	=== Read: function() --> returns data
	Reads the networking sent by the Write function. Note that bot this and the Write function occur already inside of a net.Start(). You must use net.Write* functions to accomplish this.
	For clients, this reads and returns the data that the Panel will be built on. For Servers, this reads and returns the data that will be passed to Apply.

	=== Apply: function(data) --> return true/false [SERVER]
	A function that takes the Read data from the a client, and applies the fix. This is optional; If it is nil, it will not do anything. This function is only used on the server.
	It should return true if the fixes applied correctly. Returning false will re-run Collect and update the newly mismatched data

	=== Panel: function(data) --> returns DPanel [CLIENT]
	You should generally Dock(TOP) as the panel can vary in width, but your contents can define its height. You can also have it have a PerformLayout function which will run when the panel is inserted fully.
	This panel *MUST* have a function called "GetMismatch()" which should return the data modified by the panel's controls. This is the data that will be passed on to Write from the Client, and ultimately Read from Server and Apply.


	Full walkthrough of flow of data:
		1: [SERVER] Collect collects data
		2: [SERVER] Write networks the data
		3: [CLIENT] Read reads the data
		4: [CLIENT] Panel builds the control panel to fix the mismatch
		5: [CLIENT] Write networks data returned from Panel:GetMismatch() when the client saves the changes
		6: [SERVER] Read reads fix data from client
		7: [SERVER] Apply applies fix data to solve the mismatch

	Each Extension can have exactly 1 mismatch.lua file.
	The table returned by the file can contain many keys to categorize into multiple categories. This is also the name that will appear for the mismatch.
	See "core_mismatch.lua" for an example containing all the Core's mismatch data.
]]

local cached_mismatch, mismatch_types, mismatch_count
function nzu.GetFoundMismatches() return cached_mismatch end

--[[-------------------------------------------------------------------------
Server-side execution of mismatch
---------------------------------------------------------------------------]]
if SERVER then
	function nzu.CheckMismatch()
		cached_mismatch = {}
		mismatch_types = {}
		mismatch_count = 0

		-- First, check all mismatches from Core modules
		local _,modules = file.Find("nzu/core/modules/*", "LUA")
		for k,v in pairs(modules) do
			if file.Exists("nzu/core/modules/"..v.."/mismatch.lua") then
				local tbl = include("lua/nzu/core/modules/"..v.."/mismatch.lua")
				local data = tbl.Collect()
				if data then
					mismatch_types[v] = tbl
					cached_mismatch[v] = data
					mismatch_count = mismatch_count + 1
				end
			end
		end

		-- Then do the same for all Extensions
		local _,extensions = file.Find("nzu/extensions/*", "LUA")
		for k,v in pairs(extensions) do
			if file.Exists("nzu/extensions/"..v.."/mismatch.lua") then
				local tbl = include("lua/nzu/extensions/"..v.."/mismatch.lua")
				local data = tbl.Collect()
				if data then
					mismatch_types[v] = tbl
					cached_mismatch[v] = data
					mismatch_count = mismatch_count + 1
				end
			end
		end

		if mismatch_count > 0 then return cached_mismatch end
	end

	--[[-------------------------------------------------------------------------
	Server-side Networking of found mismatches
	---------------------------------------------------------------------------]]
	util.AddNetworkString("nzu_mismatch")
	local function network_mismatch(k,v)
		net.WriteString(k)
		net.WriteBool(true)
		mismatch_types[k].Write(v)
	end

	local function get_networked_players()
		local filter = RecipientFilter()
		filter:AddAllPlayers() -- TODO: Change this so that it is only Admins/whoever this is actually relevant for
		return filter
	end

	function nzu.NetworkMismatch(ply, cat)
		if cat and cached_mismatch[cat] then
			net.Start("nzu_mismatch")
				net.WriteUInt(1, 8) -- The number of mismatches to read
				network_mismatch(cat, cached_mismatch[cat])
			net.Send(ply or get_networked_players())
			return
		end

		-- No category specified: Network all
		if mismatch_size > 0 then
			net.Start("nzu_mismatch")
				net.WriteUInt(mismatch_size, 8)
				for k,v in pairs(cached_mismatch) do
					network_mismatch(k, v)
				end
			net.Send(ply or get_networked_players())
		end
	end

	--[[-------------------------------------------------------------------------
	Server-side receiving of Client fixes
	---------------------------------------------------------------------------]]
	net.Receive("nzu_mismatch", function(len, ply)
		if nzu.HasPermission(ply, "Mismatch") then
			local num = net.ReadUInt(8)
			local changed_mismatches, num_changed = {}, 0
			for i = 1, num do
				local id = net.ReadString()
				local mtype = mismatch_types[id]
				if mtype then
					if mtype.Apply then
						local retval = mtype.Apply(mtype.Read())
						if retval ~= nil then
							if retval then
								cached_mismatch[id] = nil
								mismatch_types[id] = nil
								mismatch_count = mismatch_count - 1
							else
								cached_mismatch[id] = mtype.Collect()
							end
							table.insert(changed_mismatches, id)
							num_changed = num_changed + 1
						end
					end
				end
			end

			if num_changed > 0 then
				net.Start("nzu_mismatch")
					net.WriteUInt(num_changed, 8)
					for k,v in pairs(changed_mismatches) do
						net.WriteString(v)
						if cached_mismatch[v] then
							net.WriteBool(true)
							mismatch_types[v].Write(cached_mismatch[v])
						else
							net.WriteBool(false)
						end
					end
				net.Send(get_networked_players())
			end
		end
	end)
else


	--[[-------------------------------------------------------------------------
	Client-side receiving of Server mismatches
	---------------------------------------------------------------------------]]
	net.Receive("nzu_mismatch", function()
		local num = net.ReadUInt(8)
		for i = 1, num do
			local id = net.ReadString()
			if net.ReadBool() then
				local mtype = mismatch_types[id]
				if not mtype then
					mtype = include(file.Exists("nzu/core/modules/"..id.."/mismatch.lua", "LUA") and "lua/nzu/core/modules/"..id.."/mismatch.lua" or "lua/nzu/extensions/"..id.."/mismatch.lua")
					mismatch_types[id] = mtype
				end

				cached_mismatch[id] = mtype.Read()
				mismatch_count = mismatch_count + 1
			elseif cached_mismatch[id] then
				cached_mismatch[id] = nil
				mismatch_types[id] = nil
				mismatch_count = mismatch_count - 1
			end
		end
	end)

	--[[-------------------------------------------------------------------------
	Building a Mismatch panel
	---------------------------------------------------------------------------]]
	function nzu.CreateMismatchPanel(id)
		local mtype = mismatch_types[id]
		if mtype and mtype.Panel then return mtype.Panel(cached_mismatch[id]) end
	end
end