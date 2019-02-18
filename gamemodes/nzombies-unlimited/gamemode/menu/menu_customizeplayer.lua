--AddCSLuaFile()

local default_animations = { "idle_all_01", "menu_walk" }

CreateConVar( "cl_playercolor", "0.24 0.34 0.41", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
CreateConVar( "cl_weaponcolor", "0.30 1.80 2.10", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
CreateConVar( "cl_playerskin", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin to use, if the model has any" )
CreateConVar( "cl_playerbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups to use, if the model has any" )


nzu.AddMenuHook("CustomizePlayer", function(menu)
	-- Player color and model menu
	local sheet = vgui.Create( "DPropertySheet" )
	sheet:Dock(FILL)
	sheet:SetSkin("nZombies Unlimited")

	local sub = menu:AddPanel("Customize Player ...", 2, sheet)
	local mdl = vgui.Create("DModelPanel")
	mdl:Dock( FILL )
	mdl:SetFOV( 36 )
	mdl:SetCamPos( Vector( 0, 0, 0 ) )
	mdl:SetDirectionalLight( BOX_RIGHT, Color( 255, 160, 80, 255 ) )
	mdl:SetDirectionalLight( BOX_LEFT, Color( 80, 160, 255, 255 ) )
	mdl:SetAmbientLight( Vector( -64, -64, -64 ) )
	mdl:SetAnimated( true )
	mdl.Angles = Angle( 0, 0, 0 )
	mdl:SetLookAt( Vector( -100, 0, -22 ) )
	mdl:Hide()
	menu:ParentPanelToCenter(mdl)

	function sub:OnShown()
		mdl:Show()
	end
	function sub:OnHid()
		mdl:Hide()
		net.Start("nzu_CustomizePlayerDone")
		net.SendToServer()
	end

	--local modelcat = sheet:Add("Player Model")
	local models = vgui.Create("DPanelSelect", sheet)

	for name, model in SortedPairs(player_manager.AllValidModels()) do
		local icon = vgui.Create("SpawnIcon")
		icon:SetModel(model)
		icon:SetSize(64, 64)
		icon:SetTooltip(name)
		icon.playermodel = name

		models:AddPanel(icon, {cl_playermodel = name})
	end
	sheet:AddSheet("Player Model", models, "icon16/user.png")

	--local bgcat = sheet:Add("Bodygroups")
	local bglist = vgui.Create("DListLayout", sheet)
	sheet:AddSheet("Bodygroups", bglist, "icon16/wrench.png")

	-- Helper functions

	local function MakeNiceName( str )
		local newname = {}

		for _, s in pairs( string.Explode( "_", str ) ) do
			if ( string.len( s ) == 1 ) then table.insert( newname, string.upper( s ) ) continue end
			table.insert( newname, string.upper( string.Left( s, 1 ) ) .. string.Right( s, string.len( s ) - 1 ) ) -- Ugly way to capitalize first letters.
		end

		return string.Implode( " ", newname )
	end

	local function PlayPreviewAnimation( panel, playermodel )

		if ( !panel or !IsValid( panel.Entity ) ) then return end

		local anims = list.Get( "PlayerOptionsAnimations" )

		local anim = default_animations[ math.random( 1, #default_animations ) ]
		if ( anims[ playermodel ] ) then
			anims = anims[ playermodel ]
			anim = anims[ math.random( 1, #anims ) ]
		end

		local iSeq = panel.Entity:LookupSequence( anim )
		if ( iSeq > 0 ) then panel.Entity:ResetSequence( iSeq ) end

	end

	-- Updating

	local function UpdateBodyGroups( pnl, val )
		if ( pnl.type == "bgroup" ) then

			mdl.Entity:SetBodygroup( pnl.typenum, math.Round( val ) )

			local str = string.Explode( " ", GetConVarString( "cl_playerbodygroups" ) )
			if ( #str < pnl.typenum + 1 ) then for i = 1, pnl.typenum + 1 do str[ i ] = str[ i ] or 0 end end
			str[ pnl.typenum + 1 ] = math.Round( val )
			RunConsoleCommand( "cl_playerbodygroups", table.concat( str, " " ) )

		elseif ( pnl.type == "skin" ) then

			mdl.Entity:SetSkin( math.Round( val ) )
			RunConsoleCommand( "cl_playerskin", math.Round( val ) )

		end
	end

	local function RebuildBodygroupTab()
		bglist:Clear()

		local nskins = mdl.Entity:SkinCount() - 1
		if ( nskins > 0 ) then
			local skins = vgui.Create( "DNumSlider" )
			skins:Dock( TOP )
			skins:SetText( "Skin" )
			skins:SetDark( true )
			skins:SetTall( 50 )
			skins:SetDecimals( 0 )
			skins:SetMax( nskins )
			skins:SetValue( GetConVarNumber( "cl_playerskin" ) )
			skins.type = "skin"
			skins.OnValueChanged = UpdateBodyGroups
			
			bglist:Add( skins )

			mdl.Entity:SetSkin(GetConVarNumber("cl_playerskin"))
		end

		local groups = string.Explode( " ", GetConVarString( "cl_playerbodygroups" ) )
		local groupnum = mdl.Entity:GetNumBodyGroups() - 1
		for k = 0, groupnum do
			if ( mdl.Entity:GetBodygroupCount( k ) <= 1 ) then continue end

			local bgroup = bglist:Add("DNumSlider")
			bgroup:Dock(TOP)
			bgroup:SetText(MakeNiceName(mdl.Entity:GetBodygroupName(k)))
			bgroup:SetDark(true)
			bgroup:SetTall(50)
			bgroup:SetDecimals(0)
			bgroup.type = "bgroup"
			bgroup.typenum = k
			bgroup:SetMax( mdl.Entity:GetBodygroupCount(k) - 1)
			bgroup:SetValue(groups[k + 1] or 0)
			bgroup.OnValueChanged = UpdateBodyGroups

			mdl.Entity:SetBodygroup(k, groups[k + 1] or 0)
		end
		if groupnum == 0 then
			bglist:Add(Label("There are no bodygroups for this model."))
		end
	end

	--local plycolcat = sheet:Add("Player Color")
	local plycolp = vgui.Create("Panel", sheet)
	local plycol = plycolp:Add("DColorMixer")
	plycol:SetAlphaBar(false)
	plycol:SetPalette(false)
	plycol:Dock(FILL)
	plycol:SetSize(200, 260)
	sheet:AddSheet("Player Color", plycolp, "icon16/palette.png")

	--local wepcolcat = sheet:Add("Weapon Color")
	local wepcolp = vgui.Create("Panel", sheet)
	local wepcol = wepcolp:Add("DColorMixer")
	wepcol:SetAlphaBar(false)
	wepcol:SetPalette(false)
	wepcol:Dock(FILL)
	wepcol:SetSize(200, 260)
	wepcol:SetVector(Vector(GetConVarString("cl_weaponcolor")))
	sheet:AddSheet("Weapon Color", wepcolp, "icon16/joystick.png")

	local function UpdateFromConvars()
		local model = LocalPlayer():GetInfo( "cl_playermodel" )
		local modelname = player_manager.TranslatePlayerModel( model )
		util.PrecacheModel( modelname )
		mdl:SetModel( modelname )
		mdl.Entity.GetPlayerColor = function() return Vector( GetConVarString( "cl_playercolor" ) ) end
		mdl.Entity:SetPos( Vector( -100, 0, -61 ) )

		plycol:SetVector( Vector( GetConVarString( "cl_playercolor" ) ) )
		wepcol:SetVector( Vector( GetConVarString( "cl_weaponcolor" ) ) )

		PlayPreviewAnimation( mdl, model )
		RebuildBodygroupTab()
	end

	local function UpdateFromControls()
		RunConsoleCommand( "cl_playercolor", tostring( plycol:GetVector() ) )
		RunConsoleCommand( "cl_weaponcolor", tostring( wepcol:GetVector() ) )
	end

	plycol.ValueChanged = UpdateFromControls
	wepcol.ValueChanged = UpdateFromControls

	UpdateFromConvars()

	function models:OnActivePanelChanged( old, new )
		if ( old != new ) then -- Only reset if we changed the model
			RunConsoleCommand( "cl_playerbodygroups", "0" )
			RunConsoleCommand( "cl_playerskin", "0" )
		end

		timer.Simple( 0.1, function() UpdateFromConvars() end )
	end

	-- Hold to rotate

	function mdl:DragMousePress()
		self.PressX, self.PressY = gui.MousePos()
		self.Pressed = true
	end

	function mdl:DragMouseRelease() self.Pressed = false end

	function mdl:LayoutEntity( Entity )
		if ( self.bAnimated ) then self:RunAnimation() end

		if ( self.Pressed ) then
			local mx, my = gui.MousePos()
			self.Angles = self.Angles - Angle( 0, ( self.PressX or mx ) - mx, 0 )
			
			self.PressX, self.PressY = gui.MousePos()
		end

		Entity:SetAngles( self.Angles )
	end
end)

list.Set( "PlayerOptionsAnimations", "gman", { "menu_gman" } )

list.Set( "PlayerOptionsAnimations", "hostage01", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage02", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage03", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage04", { "idle_all_scared" } )

list.Set( "PlayerOptionsAnimations", "zombine", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "corpse", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "zombiefast", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "zombie", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "skeleton", { "menu_zombie_01" } )

list.Set( "PlayerOptionsAnimations", "combine", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "combineprison", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "combineelite", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "police", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "policefem", { "menu_combine" } )

list.Set( "PlayerOptionsAnimations", "css_arctic", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_gasmask", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_guerilla", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_leet", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_phoenix", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_riot", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_swat", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_urban", { "pose_standing_02", "idle_fist" } )