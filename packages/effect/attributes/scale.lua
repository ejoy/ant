local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local qc = require "quad_cache"
return {
    init = function (world, emittereid, attrib)
        local data = attrib.data
        local emitter = world[emittereid]._emitter
        for ii=emitter.quad_offset+1, emitter.quad_offset+emitter.quad_count do
            local s = mu.random(data.range)
            qc.set_quad_scale(ii, s)
        end
    end
}