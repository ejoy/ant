local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc, mu = mathpkg.constant, mathpkg.util


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
        local iqc = world:interface "ant.render|iqaudcache"
        local data = attrib.data
        if data.method == "sphere_random" then
            local e = world[emittereid]
            local emitter = e._emitter
            for ii=emitter.quad_offset+1, emitter.quad_offset+emitter.quad_count do
                local orientation = calc_random_orientation(data.longitude, data.latitude)
                iqc.set_quad_orientation(ii, math3d.torotation(orientation))
            end
        elseif data.method == "face_axis" then
            local e = world[emittereid]
            local emitter = e._emitter
            local orientation = math3d.torotation(data.axis)
            for ii=emitter.quad_offset+1, emitter.quad_offset+emitter.quad_count do
                iqc.set_quad_orientation(ii, orientation)
            end
        else
            error(("not support method:%s"):format(data.method))
        end
    end,
}