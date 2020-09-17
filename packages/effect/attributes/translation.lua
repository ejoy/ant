local mathpkg = import_package "ant.math"
local mu, mc = mathpkg.util, mathpkg.constant
local math3d = require "math3d"

return {
    init = function (world, emittereid, attrib)
        local iemitter = world:interface "ant.effect|iemitter"

        local data = attrib.data
        
        if data.method == "around_sphere" then
            local e = world[emittereid]
            local emitter = e._emitter

            for quadidx=emitter.quad_offset+1, emitter.quad_offset+emitter.quad_count do
                local radius = mu.random(data.radius_scale)
                iemitter.set_translate(emittereid, quadidx, {0, 0, radius})
                iemitter.translate_quad(emittereid, quadidx)
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

            for quadidx=emitter.quad_offset+1, emitter.quad_offset+emitter.quad_count do
                local pos = math3d.vector(x_op(), y_op(), z_op())
                iemitter.set_translate(emittereid, quadidx, pos)
                iemitter.translate_quad(emittereid, quadidx)
            end
        else
            error(("not support method:%s"):format(data.method))
        end
    end,
}