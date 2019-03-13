-- luacheck: globals log
local log = log and log(...) or print

local bgfx = require "bgfx"
local util = {}
util.__index = util

local property_types = {
    color = "v4",
    v4 = "v4",
    m4 = "m4",
    texture = "s",
}

local function update_texture(property, texture)
	assert(texture.type == "texture")
	assert(property_types[texture.type] == property.type)
	local stage = assert(texture.stage)
	bgfx.set_texture(stage, assert(property.handle), assert(texture.handle))
end

local function update_uniform(property, uniform)
	assert(property_types[uniform.type] == property.type)

	local value = uniform.value

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
		bgfx.set_uniform(assert(property.handle), table.unpack(value))
	else
		bgfx.set_uniform(assert(property.handle), value)
	end
end

local function update_properties(shader, properties, render_properties)
	local su = shader.uniforms	
	for name, u in pairs(su) do
		local function find_property(name, properties)
			local uniforms = properties.uniforms
			if uniforms then
				local p = uniforms[name]
				if p then
					return p
				end
			end
			local textures = properties.textures
			return textures and textures[name] or nil
		end

		local p = find_property(name, properties)
		p = p or find_property(name, render_properties.lighting)
		p = p or find_property(name, render_properties.shadow)

		if p == nil then
			log(string.format("uniform : %s, not privided, but shader program needed", name))
		else			
			if p.type == "texture" then
				update_texture(u, p)
			else
				update_uniform(u, p)
			end
		end
	end
end

function util.draw_primitive(vid, primgroup, mat, render_properties)
    bgfx.set_transform(mat)

    local material = primgroup.material
    bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
    update_properties(material.shader, primgroup.properties, render_properties)

	local prog = material.shader.prog
	
	local mg = assert(primgroup.mgroup)
	local ib, vb = mg.ib, mg.vb

	local prims = mg.primitives
	if prims == nil or next(prims) == nil then
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
			if ib and prim.start_index and prim.num_indices then
				bgfx.set_index_buffer(ib.handle, prim.start_index, prim.num_indices)
			end
			for idx, v in ipairs(vb.handles) do
				bgfx.set_vertex_buffer(idx - 1, v, prim.start_vertex, prim.num_vertices)
			end
			bgfx.submit(vid, prog, 0, i~=numprim)
		end
	end
end

function util.insert_primitive(eid, meshhandle, materials, srt, filter)	
	local mgroups = meshhandle.groups
	local cacheidx = filter._cache_idx
	local result = filter.result
	for i=1, #mgroups do
		local g = mgroups[i]
		local mc = materials[i] or materials[1]

		local r = result[cacheidx]
		if r == nil then
			r = {}
			result[cacheidx] = r
		end

		r.eid = eid
		r.mgroup = g
		r.material = mc.materialinfo
		r.properties = mc.properties
		r.srt = srt

		cacheidx = cacheidx + 1
	end

	filter._cache_idx = cacheidx
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