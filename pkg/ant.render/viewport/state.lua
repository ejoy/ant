local ecs = ...
local world = ecs.world

local setting = import_package "ant.settings"

local width, height = world.args.width, world.args.height

local DEFAULT_RESOLUTION_WIDTH <const> = 1280
local DEFAULT_RESOLUTION_HEIGHT <const> = 720

local device_viewrect = {
    x = 0,
    y = 0,
    w = width,
    h = height
}

local scene_ratio<const> = setting:get "scene/ratio"

local function calc_scene_size()
    assert(device_viewrect.h > 0)
    assert(device_viewrect.w > device_viewrect.h)
    local dr = device_viewrect.w / device_viewrect.h

    local h
    if scene_ratio then
        h = math.floor(device_viewrect.h * scene_ratio+0.5)
    else
        h = math.min(DEFAULT_RESOLUTION_HEIGHT, device_viewrect.h)
    end

    return math.floor(dr*h+0.5), h
end

local scene_viewrect = {x=0, y=0}
scene_viewrect.w, scene_viewrect.h = calc_scene_size()

local function log_viewrect(scale_vr, device_vr)
    local sceneratio<const>         = scale_vr.w/device_vr.w

    log.info("scene viewrect: ",    scale_vr.x, scale_vr.y, scale_vr.w, scale_vr.h)
    log.info("device viewport: ",   device_vr.x, device_vr.y, device_vr.w, device_vr.h)
    log.info("scene ratio: ",       sceneratio)

    log.info("device width/hegiht:", device_vr.w/device_vr.h)
    log.info("scene width/hegiht:", scale_vr.w/scale_vr.h)
end

log_viewrect(scene_viewrect, device_viewrect)

local function resize(w, h)
    device_viewrect.w, device_viewrect.h = w, h
    scene_viewrect.w, scene_viewrect.h = calc_scene_size()
end

return {
    viewrect        = scene_viewrect,
    resize          = resize,
    device_viewrect = device_viewrect,
    calc_scene_viewrect = calc_scene_viewrect
}
