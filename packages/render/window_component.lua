local ecs = ...
local world = ecs.world
local schema = world.schema

local bgfx = require "bgfx"

-- the viewport can have multi instance in one scene
schema:type "window"
    .width "int" (1)  -- use 1 to avoid divide by 0 
    .height "int" (1)

local win = ecs.component_v2 "window"

function win:init()
    bgfx.set_debug "T"
    self.isinit_size = false
    return self
end

local debug = ecs.system "debug_system"

debug.singleton "message"

function debug:update()
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
