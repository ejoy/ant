local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc, mu = mathpkg.constant, mathpkg.util

local qc = require "quad_cache"

local function calc_random_orientation(longitude_range, latitude_range)
    local longitude = math.rad(mu.random(longitude_range))
    local latitude = math.rad(mu.random(latitude_range))

    local sinlong, coslong = math.sin(longitude), math.cos(longitude)
    local sinlat, coslat = math.sin(latitude), math.cos(latitude)

    --[[ spheroidal coordinates
    x = r*sin(long)*cos(lat)
    y = r*sin(long)*sin(lat)
    z = r*cos(long)
    ]]

    return math3d.vector(sinlong*coslat, sinlong*sinlat, coslong)
end

return {
    init = function (world, emittereid, attrib)
        local data = attrib.data
        if data.method == "sphere_random" then
            local e = world[emittereid]
            local emitter = e._emitter
            qc.check_alloc_quad_srt(emitter.quad_count)
            for i=1, emitter.quad_count do
                local orientation = calc_random_orientation(data.longitude, data.latitude)
                qc.set_quad_orientation(i, math3d.torotation(orientation))
            end
        end
    end,
}