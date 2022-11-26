local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.util
local math3d    = require "math3d"

local dt_sys    = ecs.system "datatime_system"

local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"
local ilight    = ecs.import.interface "ant.light|ilight"

function dt_sys:init_world()
    
end

local function update_daytime(dt_ctrl)
    local h = dt_ctrl.hour
    h = h + dt_ctrl.speed * dt_ctrl.delta
    dt_ctrl.hour = mu.limit(h, 0, 24)
end

local function daytime_normalize(hour)
    -- we assume sun rise is hour = 6, sunset is hour = 18
    local sunrise, sunset = 6, 18
    if hour < 6 or sunset > 18 then
        return
    end

    local daylen<const> = sunset - sunrise
    local h<const> = hour - sunrise
    return h / daylen
end

local function which_polar_coord(hour)
    local t = daytime_normalize(hour)
    if not t then
        return 0, 0
    end
    local hpi<const> = math.pi * 0.5
    if 0<=t and t<0.5 then
        return 0, mu.lerp(hpi, 0, t)
    else
        return 0, mu.lerp(0, hpi, t)
    end
end

local function lerp_sun_color(dt_ctrl)
    local t = daytime_normalize(dt_ctrl.hour)
    if not t then
        local color = math3d.lerp(dt_ctrl.sunrise_color, dt_ctrl.sunset_color, t)
        local intensity = mu.lerp(dt_ctrl.sunrise_intensity, dt_ctrl.sunset_intensity, t)
        return color, intensity
    end
end

function dt_sys:data_changed()
    for e in w:select "daytime_controller:in" do
        local dt = e.daytime_controller
        update_daytime(dt)
        local theta, phi = which_polar_coord(dt.hour)

        local sundir = math3d.inverse(math3d.vector(mu.polar2xyz(theta, phi)))
        local sun = world:entity(dt.daytime_controller.sun_eid, "scene:in light:in")
        iom.set_direction(sun, sundir)

        local suncolor, sunintensity = lerp_sun_color(dt)
        ilight.set_color(sun, suncolor)
        ilight.set_intensity(sun, sunintensity)
    end
end