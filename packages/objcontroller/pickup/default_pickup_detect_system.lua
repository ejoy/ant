local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg = import_package "ant.math"
local mu      = mathpkg.util

local dpd_sys = ecs.system "default_pickup_detect_system"
local ipu = ecs.import.interface "ant.objcontroller|ipickup"
local topick_mb
local gesture_mb
local touch_mb

function dpd_sys:init()
    topick_mb = world:sub{"mouse", "LEFT"}
    gesture_mb = world:sub{"gesture", "tap"}
    touch_mb = world:sub{"touch"}
end

local function remap_xy(x, y)
    local ratio = world.args.framebuffer.ratio
    if ratio ~= nil and ratio ~= 1 then
        x, y = mu.cvt_size(x, ratio), mu.cvt_size(y, ratio)
    end
	local vp = world.args.viewport
	return x-vp.x, y-vp.y
end

function dpd_sys:data_changed()
    for _, _, state, x, y in topick_mb:unpack() do
        if state == "DOWN" then
            x, y = remap_xy(x, y)
            ipu.pick(x, y)
        end
    end

    for _, _, x, y in gesture_mb:unpack() do
        x, y = remap_xy(x, y)
        ipu.pick(x, y)
    end

    for _, state, data in touch_mb:unpack() do
        if state == "START" then
            local x, y = remap_xy(data[1].x, data[1].y)
            ipu.pick(x, y)
        end
    end
end
