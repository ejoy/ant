local ecs = ...
local bgfx = require "bgfx"
local ru = require "util"
local asset_lib     = import_package "ant.asset"

-- the viewport can have multi instance in one scene
local win = ecs.component "window" {
	width = 1,  -- use 1 to avoid divide by 0 
    height = 1,
}

function win:init()
    bgfx.set_debug "T"
    self.isinit_size = false
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
