local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg = import_package "ant.math"
local mu      = mathpkg.util

local dpd_sys = ecs.system "default_pickup_detect_system"
local ipu = ecs.import.interface "ant.objcontroller|ipickup"
local topick_mb
local gesture_mb

function dpd_sys:init()
    topick_mb = world:sub{"mouse", "LEFT"}
    gesture_mb = world:sub{"gesture", "tap"}
end

local function remap_xy(x, y)
    local nx, ny = mu.remap_xy(x, y, world.args.framebuffer.ratio)
	local vp = world.args.viewport
	return nx-vp.x, ny-vp.y
end

function dpd_sys:data_changed()
    for _, _, state, x, y in topick_mb:unpack() do
        if state == "DOWN" then
            x, y = remap_xy(x, y)
            ipu.pick(x, y)
        end
    end

    for _, _, pt in gesture_mb:unpack() do
        local x, y = remap_xy(pt.x, pt.y)
        ipu.pick(x, y)
    end
end
