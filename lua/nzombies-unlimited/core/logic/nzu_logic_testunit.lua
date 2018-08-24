
local LOGIC = {}

LOGIC.Spawnable = true
LOGIC.Category = "Debug Units"
LOGIC.AdminOnly = true

LOGIC.Name = "Debug Printer"
LOGIC.Description = "Receives inputs to print to server console. Can optionally have a delay, and fires outputs upon printing something matching set patterns."
LOGIC.Icon = "icon16/disk.png"
-- These are only used for UI; any output can be connected (you can make secret code-only outputs this way)
LOGIC.Outputs = {
	["UponPrintA"] = {
		Port = {Side = RIGHT, Pos = 10}
	},
	["UponPrintAnything"] = {
		Port = {Side = RIGHT,  Pos = 25}
	},
}

local function doprint(self, str)
	print(str)
	print(type(str), str == "A")
	if str == "A" then print("Firing output") self:Output("OnPrintA", str) end
	self:Output("UponPrintAnything", str)
end

LOGIC.Inputs = {
	["Print"] = {
		Function = function(self, activator, caller, args, ...)
			doprint(self, args)
		end,
		Port = {Side = LEFT, Pos = 5}
	},
	["TimedPrint"] = {
		AcceptInput = function(self, args)
			local strs = string.Split(args, " ")
			if strs[1] and strs[2] then
				local time = tonumber(strs[1])
				if time then
					return true, {Time = time, Str = strs[2]}, strs[1] .. " " .. strs[2]
				end
			end
			return false
		end,
		Function = function(self, activator, caller, args, ...)
			print("Receiving timed print", args)
			if args.Time then
				timer.Simple(args.Time, function()
					doprint(self, args.Str)
				end)
			end
		end
	},
}

LOGIC.Settings = {
	["SomeColor"] = {Type = TYPE_COLOR, Default = Color(255,255,255)},
	["ANumber"] = {Type = TYPE_NUMBER, Default = 1.5},
	["NetworkEfficient8BitInt"] = {
		Type = TYPE_NUMBER,
		NetSend = function(self, val)
			net.WriteInt(val, 8)
		end,
		NetRead = function(self)
			return net.ReadInt(8)
		end,
		Default = 3,
	},
	["BoolTest"] = {Type = TYPE_BOOL, Default = true},
	["VectorTest"] = {Type = TYPE_VECTOR, Default = Vector(1,2,3)},
	["AngleTest"] = {Type = TYPE_ANGLE, Default = Angle(0,180,360)},
	["MatrixTest"] = {Type = TYPE_MATRIX, Default = Matrix()},
	["ParseAtoB"] = {
		Type = TYPE_STRING,
		Default = "B",
		Parse = function(self, val)
			if val == "A" then return "B" end
			return val
		end,
	},
}

nzu.RegisterLogicUnit("nzu_logic_test", LOGIC)