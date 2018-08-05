
LOGIC.Name = "Invalid"

LOGIC.Inputs = {
	"Enable" = function(self)
		self.Enabled = true
		self:Output("OnEnabled")
	end,
	"Disable" = function(self)
		self.Enabled = false
		self:Output("OnDisabled")
	end,
}

LOGIC.Outputs = {
	"OnEnabled", "OnDisabled"
}

function LOGIC:AcceptInput(inp)
	return self.Enabled
end

-- Overriding to display icon in grey for disabled
local disabled = Color(100,100,100)
function LOGIC:GeneratePanel(panel)
	local linegaps = 5
	local height = 50
	local num = math.Max(#self.Inputs, #self.Outputs)
	height = math.Max(height, num*5)
	
	panel:SetHeight(height)
	panel.Icon = panel.Icon or panel:Add("DImage")
	panel.Icon:SetSize(40,40)
	panel.Icon:SetPos(5, height/2 - 20)
	panel.Icon:SetImage(self.Icon)
	
	-- Right here
	panel.Icon:SetImageColor(self.Enabled and color_white or disabled)
	
	panel.InputPositions = {}
	local i = 1
	for k,v in pairs(self.Inputs) do
		panel.InputPositions[k] = linegaps*i
		i = i + 1
	end
	
	panel.OutputPositions = {}
	i = 1
	for k,v in pairs(self.Outputs) do
		panel.OutputPositions[v] = linegaps*i
		i = i + 1
	end
end