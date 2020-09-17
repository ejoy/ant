local mathpkg = import_package "ant.math"
local mu = mathpkg.util

return {
    init = function (world, emittereid, attrib)
        local iemitter = world:interface "ant.effect|iemitter"
        local data = attrib.data
        local emitter = world[emittereid]._emitter
        for ii=emitter.quad_offset+1, emitter.quad_offset+emitter.quad_count do
            local s = mu.random(data.range)
            iemitter.set_scale(emittereid, ii, s)
            iemitter.scale_quad(emittereid, ii)
        end
    end
}