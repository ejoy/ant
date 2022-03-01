local ecs   = ...
local world = ecs.world
local w     = world.w

local dpd_sys = ecs.system "default_pickup_detect_system"
local ipu = ecs.import.interface "ant.objcontroller|ipickup"
local topick_mb

function dpd_sys:init()
    topick_mb = world:sub{"mouse", "LEFT"}
end

local function remap_xy(x, y)
	local tmq = w:singleton("tonemapping_queue", "render_target:in")
	local vr = tmq.render_target.view_rect
	return x-vr.x, y-vr.y
end

function dpd_sys:data_changed()
    for _, _, state, x, y in topick_mb:unpack() do
        if state == "DOWN" then
            x, y = remap_xy(x, y)
            ipu.pick(x, y)
        end
    end
end
