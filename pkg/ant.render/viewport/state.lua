local ecs = ...
local world = ecs.world

local setting = import_package "ant.settings"

local DEFAULT_RESOLUTION_WIDTH <const> = 1280
local DEFAULT_RESOLUTION_HEIGHT <const> = 720

local scene_viewrect  = {x=0, y=0,}
local device_viewrect = {x=0, y=0,}

local scene_ratio<const> = setting:get "scene/ratio"

local function calc_scene_size(refw, refh)
    assert(refh > 0)
    assert(refw > refh)
    local dr = refw / refh

    local h
    if scene_ratio then
        h = math.floor(refh * scene_ratio+0.5)
    else
        h = math.min(DEFAULT_RESOLUTION_HEIGHT, refh)
    end

    return math.floor(dr*h+0.5), h
end

local function log_viewrect()
    local vr, dvr = scene_viewrect, device_viewrect
    log.info("scene viewrect: ",    vr.x, vr.y, vr.w, vr.h)
    log.info("device viewport: ",   dvr.x, dvr.y, dvr.w, dvr.h)

    local scene_scale_ratio<const>  = vr.w/dvr.w
    log.info("scene scale ratio: ", scene_scale_ratio)

    log.info("scene width/hegiht:",  vr.w/vr.h)
    log.info("device width/hegiht:", dvr.w/dvr.h)
end

local function resize(w, h)
    device_viewrect.w, device_viewrect.h = w, h
    scene_viewrect.w, scene_viewrect.h = calc_scene_size(device_viewrect.w, device_viewrect.h)

    log_viewrect()
end

resize(world.args.width, world.args.height)

local function cvt2scenept(x, y)
    return x - device_viewrect.x, y - device_viewrect.y
end

local function set_device_viewrect(dvr)
    device_viewrect.x, device_viewrect.y = dvr.x, dvr.y
    resize(dvr.w, dvr.h)
end

return {
    viewrect            = scene_viewrect,
    device_viewrect     = device_viewrect,
    set_device_viewrect = set_device_viewrect,
    cvt2scenept         = cvt2scenept,
    resize              = resize,
}
