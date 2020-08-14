local mathpkg = import_package "ant.math"
local mu = mathpkg.util
local function random(r)
    local t = math.random()
    return mu.lerp(r[1], r[2], t)
end

local qc = require "quad_cache"
return {
    init = function (world, emittereid, attrib)
        local data = attrib.data
        local emitter = world[emittereid]._emitter
        qc.check_alloc_quad_srt(emitter.quad_count)
        for ii=1, emitter.quad_count do
            local s = random(data.range)
            qc.set_quad_scale(ii, s)
        end
    end
}