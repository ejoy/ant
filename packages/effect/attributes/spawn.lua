
return {
    init = function (world, emittereid, attrib)
        local iqc = world:interface "ant.render|iquadcache"
        local data = attrib.data
        if data.type == "const" then
            local e = world[emittereid]

            assert(e.emitter.particle_type == "quad", "only support quad data right now")
            local emitter = e._emitter
            emitter.quad_count = data.count
            emitter.quad_offset = iqc.quad_num()

            local rc = e._rendercache
            rc.vb, rc.ib = iqc.alloc_quad_buffer(data.count)
        end
    end,
}