local ecs = ...
local world = ecs.world

local setting = import_package "ant.settings"

local scene_ratio<const> = setting:get "scene/ratio"

local function resolution_limits()
    local resolution = setting:get "scene/resolution_limits"
    if resolution then
        local sw, sh = resolution:match "(%d+)x(%d+)"
        return math.tointeger(sw), math.tointeger(sh)
    end
end

local LIMIT_RESOLUTION_WIDTH, LIMIT_RESOLUTION_HEIGHT = resolution_limits()

--device_viewrect = scene_viewrect * scale
local scene_viewrect  = {x=0, y=0,}
local device_viewrect = {x=0, y=0,}

local function viewrect_ratio()
    --scene_viewrect.h/device_viewrect.h equal to scene_viewrect.w/device_viewrect.w, see: calc_scene_size
    return scene_viewrect.w/device_viewrect.w
end

local function calc_scene_size(refw, refh)
    assert(refh > 0)
    assert(refw > 0)
    local dr = refw / refh

    local h
    if scene_ratio then
        h = math.floor(refh * scene_ratio+0.5)
    elseif LIMIT_RESOLUTION_HEIGHT then
        h = math.min(LIMIT_RESOLUTION_HEIGHT, refh)
    else
        h = refh
    end

    return math.floor(dr*h+0.5), h
end

local function log_viewrect()
    local vr, dvr = scene_viewrect, device_viewrect
    log.debug("scene viewrect: ",    vr.x, vr.y, vr.w, vr.h)
    log.debug("device viewport: ",   dvr.x, dvr.y, dvr.w, dvr.h)

    local scene_scale_ratio<const>  = viewrect_ratio()
    log.debug("scene scale ratio: ", scene_scale_ratio)

    log.debug("scene width/hegiht:",  vr.w/vr.h)
    log.debug("device width/hegiht:", dvr.w/dvr.h)
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

local function scale_xy(x, y)
    local scale = viewrect_ratio()
    return x * scale, y * scale
end

--sx, sy are scale scene coordinate
local function unscale_xy(sx, sy)
    local scale = 1.0 / viewrect_ratio()
    return sx * scale, sy * scale
end

--x, y are window coordinate(device coordinate)
local function remap_xy(screen_x, scree_y)
    --x, y are coordinate in viewport, but we want to find them in scene_viewrect
    local x, y = cvt2scenept(screen_x, scree_y)
    return scale_xy(x, y)
end

local function set_resolution_limits(width, height)
    LIMIT_RESOLUTION_WIDTH, LIMIT_RESOLUTION_HEIGHT = width, height
end

return {
    viewrect            = scene_viewrect,
    device_viewrect     = device_viewrect,
    set_device_viewrect = set_device_viewrect,
    cvt2scenept         = cvt2scenept,
    remap_xy            = remap_xy,
    scale_xy            = scale_xy,
    unscale_xy          = unscale_xy,
    resize              = resize,
    set_resolution_limits= set_resolution_limits,
}
