
local PANEL = {}

AccessorFunc( PANEL, "m_bShowIcons", "ShowIcons" )
AccessorFunc( PANEL, "m_iIndentSize", "IndentSize" )
AccessorFunc( PANEL, "m_iLineHeight", "LineHeight" )
AccessorFunc( PANEL, "m_pSelectedItem", "SelectedItem" )
AccessorFunc( PANEL, "m_bClickOnDragHover", "ClickOnDragHover" )

function PANEL:Init()

	--self:SetMouseInputEnabled( true )
	--self:SetClickOnDragHover( false )

	self:SetShowIcons( true )
	self:SetIndentSize( 14 )
	self:SetLineHeight( 17 )
	--self:SetPadding( 2 )

	self.RootNode = self:GetCanvas():Add( "DConfigTree_Node" )
	self.RootNode:SetRoot( self )
	self.RootNode:SetParentNode( self )
	self.RootNode:Dock( TOP )
	self.RootNode:SetText( "" )
	self.RootNode:SetExpanded( true, true )
	self.RootNode:DockMargin( 0, 4, 0, 0 )

	self:SetPaintBackground( true )

end

--
-- Get the root node
--
function PANEL:Root()
	return self.RootNode
end

function PANEL:AddNode()

	return self.RootNode:AddNode()

end

function PANEL:ChildExpanded( bExpand )

	self:InvalidateLayout()

end

function PANEL:ShowIcons()

	return self.m_bShowIcons

end

function PANEL:ExpandTo( bExpand )
end

function PANEL:SetExpanded( bExpand )

	-- The top most node shouldn't react to this.

end

function PANEL:Clear()
	self:Root():Clear()
end

function PANEL:Paint( w, h )

	derma.SkinHook( "Paint", "Tree", self, w, h )
	return true

end

function PANEL:DoClick( node )
	return false
end

function PANEL:DoRightClick( node )
	return false
end

function PANEL:SetSelectedItem( node )

	if ( IsValid( self.m_pSelectedItem ) ) then
		self.m_pSelectedItem:SetSelected( false )
	end

	self.m_pSelectedItem = node

	if ( node ) then
		node:SetSelected( true )
		node:OnNodeSelected( node )
	end

end

function PANEL:OnNodeSelected( node )
end

function PANEL:MoveChildTo( child, pos )

	self:InsertAtTop( child )

end

function PANEL:LayoutTree()

	self:InvalidateChildren( true )

end

derma.DefineControl( "DConfigTree", "Config Tree View", PANEL, "DScrollPanel" )


PANEL = {}

AccessorFunc( PANEL, "m_pRoot", "Root" )
AccessorFunc( PANEL, "m_pParentNode", "ParentNode" )
AccessorFunc( PANEL, "m_bLastChild", "LastChild", FORCE_BOOL )

function PANEL:Init()
	self.animSlide = Derma_Anim("Anim", self, self.AnimSlide)
	self.Button = self:Add("DButton")
	self.Button:SetText("HEYHO")
	self.Button.Paint = function() end
	self.Button:SetZPos(32000)
	self.Button.DoClick = function() self:InternalDoClick() end
	self.Button.DoDoubleClick = function() self:InternalDoClick() end
	self.Button.DoRightClick = function() self:InternalDoRightClick() end
	self.Button.DragHover = function( s, t ) self:DragHover( t ) end
end

function PANEL:IsRootNode()
	return self.m_pRoot == self.m_pParentNode
end

function PANEL:InternalDoClick()
	self:GetRoot():SetSelectedItem(self)

	if (self:DoClick()) then return end
	if (self:GetRoot():DoClick(self)) then return end
	
	self:SetExpanded(!self.m_bExpanded)
end

function PANEL:OnNodeSelected( node )

	local parent = self:GetParentNode()
	if ( IsValid( parent ) && parent.OnNodeSelected ) then
		parent:OnNodeSelected( node )
	end

end

function PANEL:InternalDoRightClick()

	if ( self:DoRightClick() ) then return end
	if ( self:GetRoot():DoRightClick( self ) ) then return end

end

function PANEL:DoClick()
	return false
end

function PANEL:DoRightClick()
	return false
end

function PANEL:Clear()
	if ( IsValid( self.ChildNodes ) ) then self.ChildNodes:Clear() end
end

function PANEL:AnimSlide( anim, delta, data )

	if ( !IsValid( self.ChildNodes ) ) then anim:Stop() return end

	if ( anim.Started ) then
		data.To = self:GetTall()
		data.Visible = self.ChildNodes:IsVisible()
	end

	if ( anim.Finished ) then
		self:InvalidateLayout()
		self.ChildNodes:SetVisible( data.Visible )
		self:SetTall( data.To )
		self:GetParentNode():ChildExpanded()
		return
	end

	self.ChildNodes:SetVisible( true )

	self:SetTall( Lerp( delta, data.From, data.To ) )

	self:GetParentNode():ChildExpanded()

end

function PANEL:ShowIcons()
	return self:GetParentNode():ShowIcons()
end

function PANEL:GetLineHeight()
	return self:GetParentNode():GetLineHeight()
end

function PANEL:GetIndentSize()
	return self:GetParentNode():GetIndentSize()
end

function PANEL:ExpandRecurse( bExpand )

	self:SetExpanded( bExpand, true )

	if ( !IsValid( self.ChildNodes ) ) then return end

	for k, Child in pairs( self.ChildNodes:GetItems() ) do
		if ( Child.ExpandRecurse ) then
			Child:ExpandRecurse( bExpand )
		end
	end

end

function PANEL:ExpandTo( bExpand )

	self:SetExpanded( bExpand, true )
	self:GetParentNode():ExpandTo( bExpand )

end

function PANEL:SetExpanded( bExpand, bSurpressAnimation )

	print("Expanding", bExpand)

	self:GetParentNode():ChildExpanded( bExpand )
	self.m_bExpanded = bExpand
	self:InvalidateLayout( true )

	if ( !IsValid( self.ChildNodes ) ) then return end

	local StartTall = self:GetTall()
	self.animSlide:Stop()
	
	if ( IsValid( self.ChildNodes ) ) then
		self.ChildNodes:SetVisible( bExpand )
		if ( bExpand ) then
			self.ChildNodes:InvalidateLayout( true )
		end
	end

	self:InvalidateLayout( true )

	-- Do animation..
	if ( !bSurpressAnimation ) then
		self.animSlide:Start( 0.3, { From = StartTall } )
		self.animSlide:Run()
	end

end

function PANEL:ChildExpanded( bExpand )

	self.ChildNodes:InvalidateLayout( true )
	self:InvalidateLayout( true )
	self:GetParentNode():ChildExpanded( bExpand )

end

function PANEL:HasChildren()

	if ( !IsValid( self.ChildNodes ) ) then return false end
	return self.ChildNodes:HasChildren()

end

function PANEL:DoChildrenOrder()

	if ( !IsValid( self.ChildNodes ) ) then return end

	local last = table.Count( self.ChildNodes:GetChildren() )
	for k, Child in pairs( self.ChildNodes:GetChildren() ) do
		Child:SetLastChild( k == last )
	end

end

function PANEL:PerformRootNodeLayout()

	self.Button:SetVisible( false )

	if ( IsValid( self.ChildNodes ) ) then

		self.ChildNodes:Dock( TOP )
		self:SetTall( self.ChildNodes:GetTall() )

	end

end

function PANEL:PerformLayout()

	if ( self:IsRootNode() ) then
		return self:PerformRootNodeLayout()
	end

	if ( self.animSlide:Active() ) then return end

	local LineHeight = self:GetTall()

	self.Button:StretchToParent( 0, nil, 0, nil )
	self.Button:SetTall(LineHeight)
	--self.Button:SetTextInset( self.Expander.x + self.Expander:GetWide() + 4, 0 )

	if ( !IsValid( self.ChildNodes ) || !self.ChildNodes:IsVisible() ) then
		self:SetTall( LineHeight )
		return
	end

	self.ChildNodes:SizeToContents()
	self:SetTall( LineHeight + self.ChildNodes:GetTall() )

	self.ChildNodes:StretchToParent( LineHeight, LineHeight, 0, 0 )

	self:DoChildrenOrder()

end

function PANEL:CreateChildNodes()

	if ( IsValid( self.ChildNodes ) ) then return end

	self.ChildNodes = vgui.Create( "DListLayout", self )
	self.ChildNodes:SetDropPos( "852" )
	self.ChildNodes:SetVisible( self.m_bExpanded )
	self.ChildNodes.OnChildRemoved = function()

		self.ChildNodes:InvalidateLayout()

		-- Root node should never be closed
		if ( !self.ChildNodes:HasChildren() && !self:IsRootNode() ) then
			self:SetExpanded( false )
		end

	end

	self.ChildNodes.OnModified = function()

		self:OnModified()

	end

	self:InvalidateLayout()

end

function PANEL:AddPanel( pPanel )

	self:CreateChildNodes()

	self.ChildNodes:Add( pPanel )
	self:InvalidateLayout()

end

function PANEL:AddNode()

	self:CreateChildNodes()

	local pNode = vgui.Create( "DConfigTree_Node", self )
	pNode:SetParentNode( self )
	pNode:SetRoot( self:GetRoot() )

	self.ChildNodes:Add( pNode )
	self:InvalidateLayout()

	return pNode

end

function PANEL:InsertNode( pNode )

	self:CreateChildNodes()

	pNode:SetParentNode( self )
	pNode:SetRoot( self:GetRoot() )
	self:InstallDraggable( pNode )

	self.ChildNodes:Add( pNode )
	self:InvalidateLayout()

	return pNode

end

function PANEL:SetSelected( b )

	self.Button:SetSelected( b )
	self.Button:InvalidateLayout()

end

function PANEL:Think()

	self.animSlide:Run()

end

--
-- DragHoverClick
--
function PANEL:DragHoverClick( HoverTime )

	if ( !self.m_bExpanded ) then
		self:SetExpanded( true )
	end

	if ( self:GetRoot():GetClickOnDragHover() ) then

		self:InternalDoClick()

	end

end

function PANEL:MoveToTop()

	local parent = self:GetParentNode()
	if ( !IsValid(parent) ) then return end

	self:GetParentNode():MoveChildTo( self, 1 )

end

function PANEL:MoveChildTo( child )

	self.ChildNodes:InsertAtTop( child )

end

function PANEL:CleanList()

	for k, panel in pairs( self.Items ) do

		if ( !IsValid( panel ) || panel:GetParent() != self.pnlCanvas ) then
			self.Items[k] = nil
		end

	end

end

function PANEL:Insert( pNode, pNodeNextTo, bBefore )

	pNode:SetParentNode( self )
	pNode:SetRoot( self:GetRoot() )

	self:CreateChildNodes()

	if ( bBefore ) then
		self.ChildNodes:InsertBefore( pNodeNextTo, pNode )
	else
		self.ChildNodes:InsertAfter( pNodeNextTo, pNode )
	end

	self:InvalidateLayout()

end

function PANEL:LeaveTree( pnl )

	self.ChildNodes:RemoveItem( pnl, true )
	self:InvalidateLayout()

end

function PANEL:OnModified()

	-- Override Me

end

function PANEL:GetChildNode( iNum )

	if ( !IsValid( self.ChildNodes ) ) then return end
	return self.ChildNodes:GetChild( iNum )

end

derma.DefineControl( "DConfigTree_Node", "Config Tree Node", PANEL, "DPanel" )
