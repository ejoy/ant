local ecs = ...
local world = ecs.world

local setting = import_package "ant.settings"
local mu = import_package "ant.math".util

local width, height = world.args.width, world.args.height

local SCENE_RATIO <const> = setting:get "scene/scene_ratio" or 1.0
local RESOLUTION_WIDTH <const> = 1280
local RESOLUTION_HEIGHT <const> = 720

local function get_resolution()
    local w, h
    w, h = (setting:get "scene/resolution"):match "(%d+)%a(%d+)"
    return {w = tonumber(w and w or RESOLUTION_WIDTH), h = tonumber(h and h or RESOLUTION_HEIGHT)}
end

local resolution = get_resolution()

local vp = {
    x = 0,
    y = 0,
    w = width,
    h = height
}

local vr = mu.get_scene_view_rect(resolution, vp, SCENE_RATIO)

log.info("scene viewrect: ", vr.x, vr.y, vr.w, vr.h)
log.info("scene ratio: ", SCENE_RATIO)
log.info("device viewport: ", vp.x, vp.y, vp.w, vp.h)

return {
    viewrect = vr,
    resolution = resolution,
    scene_ratio = SCENE_RATIO,
    device_size = vp,
}
