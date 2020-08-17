local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant
local math3d = require "math3d"
local qc = require "quad_cache"

return {
    init = function (world, emittereid, attrib)
        local data = attrib.data
        
        if data.method == "around_sphere" then
            local e = world[emittereid]
            local emitter = e._emitter
            qc.check_alloc_quad_srt(emitter.quad_count)
            for ii=1, emitter.quad_count do
                local radius = mu.random(data.radius_scale)
                local q = qc.quad_srt(ii).r
                local n = math3d.transform(q, mc.ZAXIS, 0)
                qc.set_quad_translate(ii, math3d.mul(radius, n))
            end
        end
    end,
}