local ecs = ...

local bgfx = require "bgfx"


local win = ecs.singleton_component "window"

function win:init()
    bgfx.set_debug "T"
    return {
        width = 1,
        height = 1,
        isinit_size = false
    }
end

local debug = ecs.system "debug_system"

debug.singleton "message"

function debug:init()
    local message = {}
    local enable = false
    function message:keyboard(c, p)
		if c == nil then return end
        if c == "I" then
            enable = p
            bgfx.set_debug(enable and "ST" or "T")
		end
	end
	self.message.observers:add(message)
end
