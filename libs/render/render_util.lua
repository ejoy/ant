local bgfx = require "bgfx"

local util = {}

function util.foreach_comp(w, comp_names, op)
    for _, eid in w:each(comp_names[1]) do
        local meshentity = w[eid]
        if meshentity ~= nil then
            local function is_entity_have_components(beg_idx, end_idx)
                while beg_idx <= end_idx do
                    if meshentity[comp_names[beg_idx]] == nil then
                        return false
                    end
                    beg_idx = beg_idx + 1
                end
                return true
            end
        
            if is_entity_have_components(2, #comp_names) then
                op(meshentity)
            end
        end
    end
end

function util.foreach_sceneobj(w, op)
    local comps = util.get_scene_objcompoent_names()
    util.foreach_comp(w, comps, op)
end

function util.submit_mesh(mesh, shader)
    local prog = assert(shader.prog)
    local num = #mesh.group

    for i=1, num do
        local g = mesh.group[i]
        bgfx.set_index_buffer(g.ib)
        bgfx.set_vertex_buffer(g.vb)
        bgfx.submit(0, prog, 0, i ~= num)
    end
end

function util.update_uniforms(uniforms) 
    --for i = 1, #uniforms do    
    for _, u in pairs(uniforms) do
        local value = u:update()
        bgfx.set_uniform(u.id, value)
    end
end

function util.draw_entity(meshentity, worldmat)    
    bgfx.set_transform(worldmat)
    local render = meshentity.render
    util.draw_mesh(render.mesh, render.material)
end

function util.draw_mesh(mesh, material)
    bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
    
    util.update_uniforms(material.uniform)
    util.submit_mesh(mesh.handle, material.shader)
end

return util