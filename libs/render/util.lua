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
        util.draw_entity(vid, entity, ms)
    end)
end

function util.update_uniform(u) 
    if u.update then
        u:update()
    end
    local id = assert(u.id)
    local value = assert(u.value)    
    bgfx.set_uniform(id, value)
end

function util.draw_entity(vid, entity, ms)    
    local render = entity.render
    if 1 then
        local rinfo = render.info
        local uniforms = assert(render.uniforms)
        for idx, elem in ipairs(rinfo) do
            local esrt= elem.srt
            local mat = ms({type="srt", s=esrt.s, r=esrt.r, t=esrt.t}, 
                            {type="srt", s=entity.scale.v, r=entity.rotation.v, t=entity.position.v}, 
                            "*m")            
            util.draw_mesh(vid, elem.mesh, elem.binding, uniforms, mat)
        end
    end
end

function util.draw_mesh(vid, mesh, bindings, uniforms, worldmat)
    bgfx.set_transform(worldmat)

    local mgroups = mesh.handle.group
    for _, binding in ipairs(bindings) do
        local material = binding.material

        bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str

        local prog = assert(material.shader.prog)        
        local muniforms = assert(uniforms[material.name])

        local uniform_names = material.uniform        
        for _, n in ipairs(uniform_names) do
            local u = muniforms[n]
            if u == nil then
                print(string.format("material : %s need uniform : %s, but not define", material.name, n))
            else
                util.update_uniform(u)
            end
        end

        local meshids = binding.meshids
        local num = #meshids

        for i=1, num do
            local id = meshids[i]
            local g = assert(mgroups[id])
            if g.ib then
                bgfx.set_index_buffer(g.ib)
            end
            bgfx.set_vertex_buffer(g.vb)
            bgfx.submit(vid, prog, 0, i ~= num)
        end
    end
end

function util.create_uniform(name, type, value, update)    
    local id = bgfx.create_uniform(name, type)
    return {id=assert(id), name=name, type=type, value=value, update=update}
end

return util