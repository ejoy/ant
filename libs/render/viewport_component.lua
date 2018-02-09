-- we need something call renderpipeline component to abstract the render pipeline
-- that's because we will have multi render target in one frame
-- and one render target should pass through render pipeline one time.
-- the render pipeline system should only one, but if we want to support multi render target
-- we need multi render pipeline component, or call it render target
-- right now, we just assume only one render target

local ecs = ...
local bgfx = require "bgfx"

-- the viewport can have multi instance in one scene
local vp = ecs.component "viewport" { --may call viewport?
    x = 0,
    y = 0,
	width = 1,  -- use 1 to avoid divide by 0 
    height = 1,
    clear_color = 0x303030ff,
    clear_depth = 1,
    clear_stencil = 0,    
}

function vp:init()
    -- runtime var
    self.need_clear_color = true
    self.need_clear_depth = true
    self.need_clear_stencil = true
end

local viewport_sys = ecs.system "viewport_system"
viewport_sys.singleton "viewport"

local function clear_framebuffer(vp_comp)
    -- todo: bgfx should privide clear color/depth/stencil methods
    bgfx.set_view_clear(0, "CD", vp_comp.clear_color, vp_comp.clear_depth, vp_comp.clear_stencil)	
end

function viewport_sys:init()
	clear_framebuffer(self.viewport)
	bgfx.set_debug "T"
end

function viewport_sys:update()
    clear_framebuffer(self.viewport)
end