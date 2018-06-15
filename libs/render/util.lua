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
    texture = {type="i1",}
}

local function update_property(name, property)
	local uniform = shadermgr.get_uniform(name)        
	if uniform == nil  then
		log("property name : ", name, ", is needed, but shadermgr not found!")
		return 
	end

	assert(uniform.name == name)
	assert(property_type_description[property.type].type == uniform.type)
	
	if property.type == "texture" then
		local stage = assert(property.stage)
		bgfx.set_texture(stage, assert(uniform.handle), assert(property.value))
	else	
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