local ecs = ...
local bgfx = require "bgfx"
local ru = require "render.util"
local asset_lib     = require "asset"

-- the viewport can have multi instance in one scene
local win = ecs.component_struct "window" {
	width = 1,  -- use 1 to avoid divide by 0 
    height = 1,
}

function win:init()
    bgfx.set_debug "T"
    self.isinit_size = false
end