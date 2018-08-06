ENT.Type = "point"
function ENT:Initialize()
	self:SetLogicType(self.LogicType)
	--self:SetLogicConnections({})
end

function ENT:GetConnections()
	return self.LOGIC_CONNECTIONS
end

function ENT:GetLogicID()

end

function ENT:AcceptConnection(from, inp)

end

function ENT:AcceptInput(inp, activator, caller, data)
	if not self:AllowInput(inp, activator, caller, data) then return end

	local f = self.LogicInputs[inp]
	if f then f(self, activator, caller, data) end
end

function ENT:Output(outp, caller)
	local c = self:GetConnections()
	if c and c[outp] then
		for k,v in pairs(c[outp]) do
			if IsValid(k) then
				for k2,v2 in pairs(v) do
					v:Input(k2, self, caller, v2)
				end
			end
		end
	end
end

function ENT:AllowInput(inp, activator, caller, data)
	return true
end