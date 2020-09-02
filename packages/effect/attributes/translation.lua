local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant
local math3d = require "math3d"

return {
    init = function (world, emittereid, attrib)
        local iqc = world:interface "ant.render|iquadcache"
        local data = attrib.data
        
        if data.method == "around_sphere" then
            local e = world[emittereid]
            local emitter = e._emitter
            
            for ii=emitter.quad_offset+1, emitter.quad_offset+emitter.quad_count do
                local radius = mu.random(data.radius_scale)
                local q = iqc.quad_srt(ii).r
                local n = math3d.transform(q, mc.ZAXIS, 0)
                iqc.set_quad_translate(ii, math3d.mul(radius, n))
            end
        elseif data.method == "around_box" then
            local e = world[emittereid]
            local emitter = e._emitter
            local br = data.box_range
            
            local function random_op(r) return r and 
                function () return mu.random(r) end or 
                function() return 0 end 
            end
            local x_op, y_op, z_op = random_op(br.x), random_op(br.y), random_op(br.z)

            for ii=emitter.quad_offset+1, emitter.quad_offset+emitter.quad_count do
                local pos = math3d.vector(x_op(), y_op(), z_op())
                iqc.set_quad_translate(ii, pos)
            end
        else
            error(("not support method:%s"):format(data.method))
        end
    end,
}