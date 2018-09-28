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
		-- log(string.format("property name : %s, is needed, but shadermgr not found!", name))
		return 
	end

	assert(uniform.name == name)
	assert(property_type_description[property.type].type == uniform.type)
	
	if property.type == "texture" then
		local stage = assert(property.stage)
		bgfx.set_texture(stage, assert(uniform.handle), assert(property.value))
	else
		local val = assert(property.value)

		local function need_unpack(val)
			if type(val) == "table" then
				local elemtype = type(val[1])
				if elemtype == "table" or elemtype == "userdata" or elemtype == "luserdata" then
					return true
				end
			end
			return false
		end
		
		if need_unpack(val) then
			bgfx.set_uniform(assert(uniform.handle), table.unpack(val))
		else
			bgfx.set_uniform(assert(uniform.handle), val)
		end
		
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

function util.draw_primitive(vid, primgroup, mat)
    bgfx.set_transform(mat)

    local material = primgroup.material
    bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
    update_properties(material.shader, primgroup.properties)

	local prog = material.shader.prog
	
	local mg = assert(primgroup.mgroup)
	local ib, vb = mg.ib, mg.vb

	local prims = mg.prim

	local numprim = prims and #prims or nil
	if numprim == nil or numprim == 1 then
		if ib then
			bgfx.set_index_buffer(ib.handle)
		end
		for idx, v in ipairs(vb.handles) do
			bgfx.set_vertex_buffer(idx, v)
		end
		
		bgfx.submit(vid, prog, 0, false)
	else
		for i=1, numprim do
			local prim = prims[i]
			if ib then
				bgfx.set_index_buffer(ib.handle, prim.startIndex, prim.numIndices)
			end
			for idx, v in ipairs(vb.handles) do
				bgfx.set_vertex_buffer(idx, v, prim.startVertex, prim.numVertices)
			end
			bgfx.submit(vid, prog, 0, i~=numprim)
		end
	end
end

function util.default_surface_type()
	return {
		lighting = "on",			-- "on"/"off"
		transparency = "opaticy",	-- "opaticy"/"transparent"
		shadow	= {
			cast = "on",			-- "on"/"off"
			receive = "on",			-- "on"/"off"
		},
		subsurface = "off",			-- "on"/"off"? maybe has other setting
	}
end

return util