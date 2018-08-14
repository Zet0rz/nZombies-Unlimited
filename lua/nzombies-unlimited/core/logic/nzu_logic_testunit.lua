
local LOGIC = {}

-- These are only used for UI; any output can be connected (you can make secret code-only outputs this way)
LOGIC.Outputs = {
	"UponPrintA", "UponPrintAnything"
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
		end
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
	["SomeColor"] = {Type = TYPE_COLOR},
	["ANumber"] = {Type = TYPE_NUMBER},
	["NetworkEfficient8BitInt"] = {
		NetSend = function(self, val)
			net.WriteInt(val, 8)
		end,
		NetRead = function(self)
			return net.ReadInt(8)
		end,
	}
}

nzu.RegisterLogicUnit("nzu_logic_test", LOGIC)