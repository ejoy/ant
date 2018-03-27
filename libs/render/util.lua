local bgfx = require "bgfx"
local cu = require "render.components.util"
local mu = require "math.util"
local util = {}

function util.foreach_entity(w, comp_names, op)
    for _, eid in w:each(comp_names[1]) do
        local entity = w[eid]
        if entity ~= nil then
            local function is_entity_have_components(beg_idx, end_idx)
                while beg_idx <= end_idx do
                    if entity[comp_names[beg_idx]] == nil then
                        return false
                    end
                    beg_idx = beg_idx + 1
                end
                return true
            end
        
            if is_entity_have_components(2, #comp_names) then
                op(entity, eid)
            end
        end
    end
end

function util.foreach_sceneobj(w, op)
    local comps = cu.get_sceneobj_compoent_names()
    util.foreach_entity(w, comps, op)
end

function util.draw_scene(vid, world, ms)
    util.foreach_sceneobj(world,
    function (entity)
        util.draw_entity(vid, entity, mu.srt_from_entity(ms, entity))
    end)
end

function util.submit_mesh(vid, mesh, shader)
    local prog = assert(shader.prog)
    local num = #mesh.group

    for i=1, num do
        local g = mesh.group[i]
        bgfx.set_index_buffer(g.ib)
        bgfx.set_vertex_buffer(g.vb)
        bgfx.submit(vid, prog, 0, i ~= num)
    end
end

function util.update_uniforms(uniforms) 
    --for i = 1, #uniforms do
    for _, u in pairs(uniforms) do
        local value = u:update()
        bgfx.set_uniform(u.id, value)
    end
end

function util.draw_entity(vid, entity, worldmat)    
    local render = entity.render
    util.draw_mesh(vid, render.mesh, render.binding, worldmat)
end

function util.draw_mesh(vid, mesh, bindings, worldmat)
    bgfx.set_transform(worldmat)

    local mgroups = mesh.handle.group

    for _, binding in ipairs(bindings) do
        local material = binding.material
        local prog = assert(material.shader.prog)

        bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
        util.update_uniforms(material.uniform.defines)

        local groupids = binding.groupids
        local num = #groupids

        for i=1, num do
            local id = groupids[i]
            local g = assert(mgroups[id])
            bgfx.set_index_buffer(g.ib)
            bgfx.set_vertex_buffer(g.vb)
            bgfx.submit(vid, prog, 0, i ~= num)
        end
    end
end

return util