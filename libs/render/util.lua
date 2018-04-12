local log = log and log(...) or print

local bgfx = require "bgfx"
local cu = require "render.components.util"
local mu = require "math.util"
local shadermgr = require "render.resources.shader_mgr"

local util = {}
util.__index = util

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
    local uniform = shadermgr.get_uniform(assert(u.name))
    local setter = u.setter
    local value = setter and setter(u) or u.value     
    bgfx.set_uniform(assert(uniform.handle), assert(value))
end

function util.draw_entity(vid, entity, ms)    
    local render = entity.render    
    local name = entity.name.n   
    if render.visible then                
        local rinfo = render.info        
        for idx, elem in ipairs(rinfo) do
            local esrt= elem.srt
            local mat = ms({type="srt", s=esrt.s, r=esrt.r, t=esrt.t}, 
                            {type="srt", s=entity.scale.v, r=entity.rotation.v, t=entity.position.v}, "*m")            
            local uniforms = render.uniforms and render.uniforms[idx] or nil
            util.draw_mesh(vid, elem.mesh, elem.binding, uniforms, mat)
        end
    end
end

local function check_uniform_is_match_with_shader(shader, uniforms)
    local su = shader.uniforms
    for name in pairs(su) do
        local function has_uniform(name)
            for _, u in ipairs(uniforms) do
                if u.name == name then
                    return true
                end
            end

            return false
        end
    
        if not has_uniform(name) then
            log(string.format("uniform : %s, not privided, but shader program needed", name))
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
        -- check and update uniforms
        if uniforms then            
            check_uniform_is_match_with_shader(material.shader, uniforms)
            for _, u in ipairs(uniforms) do
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

return util