--luacheck: globals iup

local probe = {}; probe.__index = probe


local ctrlutil = require "util"
local observer = require "common.observer"

function probe:add_probe(name, cb)
	self.observers:add("fetch_asset", name, cb)	
end

function probe.new(config)
	local c = ctrlutil.create_ctrl_wrapper(function ()	
		local name = config and config.NAME or "PROBE"
		return iup.button {
			NAME = name,
			TITLE="!",
			action = function (self)
				error("not implement")
			end,
		}
	
	end, probe)

	c.observers = observer.new()
	return c
end

return probe