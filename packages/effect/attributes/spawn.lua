
local function init_mesh(rc, vb, ib)
    rc.vb.start = vb.start
    rc.vb.num = vb.num
    rc.vb.handles = vb.handles

    if ib then
        rc.ib.start = ib.start
        rc.ib.num = ib.num
        rc.ib.handle = ib.handle
    else
        rc.ib = nil
    end
end

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
            local vb, ib = iqc.alloc_quad_buffer(data.count)
            init_mesh(rc, vb, ib)

            iqc.submit_patch(emitter.quad_offset, emitter.quad_count)
        end
    end,
}