-- luacheck: globals log
local log = log and log(...) or print

local bgfx = require "bgfx"
local shadermgr = require "resources.shader_mgr"

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

local property_types = {
    color = "v4",
    v4 = "v4",
    m4 = "m4",
    texture = "s",
}

local function update_textures(textures)
	if textures == nil then
		return
	end

	for name, tex in pairs(textures) do
		local uniform = shadermgr.get_uniform(name)
		if uniform then
			assert(tex.type == "texture")
			assert(property_types[tex.type] == uniform.type)
			local stage = assert(tex.stage)
			bgfx.set_texture(stage, assert(uniform.handle), assert(tex.handle))
		end
	end
end

local function update_uniforms(uniforms)
	if uniforms == nil then
		return
	end

	for name, uniformproperty in pairs(uniforms) do
		local uniform = shadermgr.get_uniform(name)
		if uniform then
			assert(uniformproperty.type)
			assert(property_types[uniformproperty.type] == uniform.type)

			local value = uniformproperty.value

			local function need_unpack(val)
				if type(val) == "table" then
					local elemtype = type(val[1])
					if elemtype == "table" or elemtype == "userdata" or elemtype == "luserdata" then
						return true
					end
				end
				return false
			end
			
			if need_unpack(value) then
				bgfx.set_uniform(assert(uniform.handle), table.unpack(value))
			else
				bgfx.set_uniform(assert(uniform.handle), value)
			end
		end
	end
end

local function fetch_properties(properties)
	local function add_properties(pp, subproperties)
		if pp == nil then
			return
		end

		if pp.uniforms then
			subproperties[#subproperties+1] = pp.uniforms
		end

		if pp.textures then
			subproperties[#subproperties+1] = pp.textures
		end
	end

	local subproperties = {}
	add_properties(properties, subproperties)
	add_properties(properties.internal, subproperties)
	return subproperties
end

local function check_uniform_is_match_with_shader(shader, properties)
	local su = shader.uniforms
	local allproperties = fetch_properties(properties)
    for name, u in pairs(su) do
		local function find_property(name, allproperties)
			for _, sub in ipairs(allproperties) do
				for k, p in pairs(sub) do
					if k == name then
						return p
					end
				end
			end
			return nil
		end

		local function check_property(name, allproperties)			
			local p = find_property(name, allproperties)
			if p == nil then             
				log(string.format("uniform : %s, not privided, but shader program needed", name))
			else
				local ptype = property_types[p.type]
				if ptype ~= u.type then
					log(string.format("uniform type : %s, property type : %s/%s, not match", u.type, p.type, ptype))
				end
			end
		end
		
		check_property(name, allproperties)		
    end
end

local function update_properties(shader, properties)
	if properties then		
		check_uniform_is_match_with_shader(shader, properties)
		
		local function update(properties)
			if properties then
				update_uniforms(properties.uniforms)
				update_textures(properties.textures)
			end
		end

		update(properties)
		update(properties.internal)
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
	if prims == nil then
		if ib then
			bgfx.set_index_buffer(ib.handle)
		end
		for idx, v in ipairs(vb.handles) do
			bgfx.set_vertex_buffer(idx - 1, v)
		end
		
		bgfx.submit(vid, prog, 0, false)
	else
		local numprim = #prims
		for i=1, numprim do
			local prim = prims[i]
			if ib and prim.startIndex and prim.numIndices then
				bgfx.set_index_buffer(ib.handle, prim.startIndex, prim.numIndices)
			end
			for idx, v in ipairs(vb.handles) do
				bgfx.set_vertex_buffer(idx - 1, v, prim.startVertex, prim.numVertices)
			end
			bgfx.submit(vid, prog, 0, i~=numprim)
		end
	end
end

function util.insert_primitive(eid, meshhandle, materials, srt, result)
	local mgroups = meshhandle.groups
	for i=1, #mgroups do
		local g = mgroups[i]
		local mc = materials[i] or materials[1]
		local material = mc.materialinfo
		local properties = mc.properties

		table.insert(result, {
			eid = eid,
			mgroup = g,
			material = material,
			properties = properties,
			srt = srt,
		})
	end
end

-- render to shadowmap




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