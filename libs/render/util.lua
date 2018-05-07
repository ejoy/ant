local log = log and log(...) or print

local bgfx = require "bgfx"
local cu = require "render.components.util"
local mu = require "math.util"
local shadermgr = require "render.resources.shader_mgr"

local util = {}
util.__index = util

-- function util.foreach_entity(w, comp_names, op)
--     for _, eid in w:each(comp_names[1]) do
--         local entity = w[eid]
--         if entity ~= nil then
--             local function is_entity_have_components(beg_idx, end_idx)
--                 while beg_idx <= end_idx do
--                     if entity[comp_names[beg_idx]] == nil then
--                         return false
--                     end
--                     beg_idx = beg_idx + 1
--                 end
--                 return true
--             end
        
--             if is_entity_have_components(2, #comp_names) then
--                 op(entity, eid)
--             end
--         end
--     end
-- end

local property_type_description = {
    color = {type="v4", },
    v4 = {type="v4",},
    texture = {
        type="",
    }
}

local function update_property(name, property)
    if property.type == "texture" then
        assert(false, "not implement texture property")
    else
        local uniform = shadermgr.get_uniform(name)        
        -- if uniform.name ~= property.name then
        --     log(string.format("we assume property name is equal to uniform internal name, 
        --                 uniform name : %s, property name : %s", uniform.name, property.name))
        --     return 
        -- end

        assert(uniform.name == name)
        assert(property_type_description[property.type].type == uniform.type)

        bgfx.set_uniform(assert(uniform.handle), assert(property.value))
    end
    

end

local function check_uniform_is_match_with_shader(shader, properties)
    local su = shader.uniforms
    for name, u in pairs(su) do
        local function find_property(name)
            for k, p in pairs(properties) do
                if k == name then
                    return p
                end
            end

            return nil
        end
    
        local p = find_property(name)
        if p == nil then             
            log(string.format("uniform : %s, not privided, but shader program needed", name))
        else
            local ptype = property_type_description[p.type]
            if ptype.type ~= u.type then
                log(string.format("uniform type : %s, property type : %s/%s, not match", u.type, p.type, ptype.type))
            end
        end
    end
end

local function update_properties(shader, properties)
    if properties then
        check_uniform_is_match_with_shader(shader, properties)
        for n, p in pairs(properties) do
            update_property(n, p)
        end
    end
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

function util.draw_mesh(vid, mesh, bindings, uniforms, worldmat)
    bgfx.set_transform(worldmat)
    local mgroups = mesh.handle.group
    for _, binding in ipairs(bindings) do
        local material = binding.material

        bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str

        local prog = assert(material.shader.prog)
        -- check and update uniforms
        update_properties(material.shader, uniforms)

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


local material_cache = nil
local function need_commit(material)
    local need = false
    if material_cache then
        need = material ~= material_cache
    end

    material_cache = material
    return need
end


function util.draw_primitive(vid, prim, mat)
    bgfx.set_transform(mat)

    local material = prim.material
    bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
    update_properties(material.shader, prim.properties)

    local mg = assert(prim.mgroup)
    local prog = material.shader.prog
    if mg.ib then
        bgfx.set_index_buffer(mg.ib)
    end
    bgfx.set_vertex_buffer(mg.vb)
    bgfx.submit(vid, prog, 0, false) --not need_commit(material))
end

return util