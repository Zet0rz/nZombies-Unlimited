local PANEL = {}

Derma_Install_Convar_Functions(PANEL)
DEFINE_BASECLASS("DComboBox")

AccessorFunc(PANEL, "m_bAllowCustomEntry", "AllowCustomInput", FORCE_BOOL)

function PANEL:OpenMenu(p)

	self.Menu = vgui.Create("EditablePanel", self)
	self.Menu:SetDrawOnTop(true)

	local txt = vgui.Create("DTextEntry", self.Menu)
	txt:Dock(TOP)
	txt:SetText(self:GetOptionText(self.selected) or "")
	txt:SetTall(20)
	txt:SetUpdateOnType(true)
	txt.OnValueChange = function(s,str)
		self:FilterMenu(str)
	end
	txt:SelectAllOnFocus()

	self.Filter = self.Menu:Add("DMenu")
	self.Filter:SetMinimumWidth(self:GetWide())
	self.Filter:Dock(FILL)

	self:FilterMenu("")
	self.Menu:SetWide(self.Filter:GetWide()) -- Max width as all options are available with empty string search
	
	local x, y = self:LocalToScreen(0, self:GetTall())
	self.Menu:SetPos(x,y)

	self.Menu:SetKeyboardInputEnabled(true)
	self.Menu:MakePopup()

	txt:SelectAllOnFocus()
	txt:RequestFocus()

	txt.OnEnter = function()
		if self:GetAllowCustomInput() then
			self:ChooseOption(txt:GetText(), 0)
		end
	end

	self.Filter.OnRemove = function()
		if IsValid(self.Menu) then
			self.Menu:KillFocus()
			self.Menu:Remove()
		end
	end
end

function PANEL:FilterMenu(str)
	if IsValid(self.Filter) and IsValid(self.Menu) then
		self:OnFilter(str)

		local tbl = {}
		for k,v in pairs(self.Choices) do
			if k > 0 and string.find(v:lower(), str:lower()) then
				tbl[k] = v
			end
		end

		self.Filter:Clear()

		-- Copy/pasted from DComboBox
		if self:GetSortItems() then
			local sorted = {}
			for k,v in pairs(tbl) do
				local val = tostring( v ) --tonumber( v ) || v -- This would make nicer number sorting, but SortedPairsByMemberValue doesn't seem to like number-string mixing
				if (string.len( val ) > 1 and not tonumber( val ) and val:StartWith( "#" )) then val = language.GetPhrase( val:sub( 2 )) end
				table.insert( sorted, { id = k, data = v, label = val } )
			end
			for k,v in SortedPairsByMemberValue( sorted, "label" ) do
				local option = self.Filter:AddOption( v.data, function() self:ChooseOption(v.data, v.id) end )
				if (self.ChoiceIcons[ v.id ]) then
					option:SetIcon( self.ChoiceIcons[ v.id ] )
				end
			end
		else
			for k,v in pairs(tbl) do
				local option = self.Filter:AddOption( v, function() self:ChooseOption(v, k) end )
				if ( self.ChoiceIcons[ k ] ) then
					option:SetIcon( self.ChoiceIcons[ k ] )
				end
			end
		end

		self.Filter:PerformLayout()
		self.Menu:SetTall(self.Filter:GetTall() + 20)
	end
end

function PANEL:OnFilter(str) end

function PANEL:ChooseOption(value, index)
	if index == 0 then
		self.Choices[0] = value
		self.Data[0] = value
	else
		self.Choices[0] = nil
		self.Data[0] = nil
	end

	BaseClass.ChooseOption(self, value, index)
	self:ConVarChanged(self.Data[index] or value)
end

derma.DefineControl("DSearchComboBox", "", PANEL, "DComboBox")