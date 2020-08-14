local qc = require "quad_cache"

return {
    init = function (world, emittereid, attrib)
        local data = attrib.data
        if data.type == "const" then
            local e = world[emittereid]

            assert(e.emitter.particle_type == "quad", "only support quad data right now")
            local emitter = e._emitter
            emitter.quad_count = data.count
            emitter.quad_offset = qc.quad_num()

            local rc = e._rendercache
            rc.vb, rc.ib = qc.alloc_quad_buffer(data.count)
        end
    end,
}