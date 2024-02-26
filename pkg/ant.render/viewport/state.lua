local ecs = ...
local world = ecs.world

local setting = import_package "ant.settings"

local width, height = world.args.width, world.args.height

local DEFAULT_RESOLUTION_WIDTH <const> = 1280
local DEFAULT_RESOLUTION_HEIGHT <const> = 720

local device_viewrect<const> = {
    x = 0,
    y = 0,
    w = width,
    h = height
}

local function get_resolution()
    local native = setting:get "scene/resolution/native"
    if native then
        return device_viewrect
    end
    local r = setting:get "scene/resolution/size"
    if r then
        local w, h = r:match "(%d+)%a(%d+)"
        local _ = w or error(("Invalid scene/resolution define:%s, it should be define like this: 1280x720"):format(r))
        return {x=0, y=0, w=tonumber(w), h=tonumber(h)}
    end
end

local custom_vr<const> = get_resolution()

local function calc_scene_viewrect()
    assert(device_viewrect.h > 0)
    assert(device_viewrect.w > device_viewrect.h)
    local r = device_viewrect.w / device_viewrect.h
    local h = math.min(DEFAULT_RESOLUTION_HEIGHT, device_viewrect.h)

    return {
        x=0, y=0,
        w=math.floor(r*h+0.5), h=h,
    }
end

local scene_viewrect<const> = custom_vr and custom_vr or calc_scene_viewrect()

local function log_viewrect(scale_vr, device_vr)
    local sceneratio<const>         = scale_vr.w/device_vr.w

    log.info("scene viewrect: ",    scale_vr.x, scale_vr.y, scale_vr.w, scale_vr.h)
    log.info("device viewport: ",   device_vr.x, device_vr.y, device_vr.w, device_vr.h)
    log.info("scene ratio: ",       sceneratio)

    log.info("device width/hegiht:", device_vr.w/device_vr.h)
    log.info("scene width/hegiht:", scale_vr.w/scale_vr.h)
end

log_viewrect(scene_viewrect, device_viewrect)

return {
    viewrect        = scene_viewrect,
    custom_vr       = custom_vr,
    device_viewrect = device_viewrect,
    calc_scene_viewrect = calc_scene_viewrect
}
