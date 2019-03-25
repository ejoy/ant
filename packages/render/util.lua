-- luacheck: globals log
local log = log and log(...) or print

local bgfx = require "bgfx"
local viewidmgr = require "viewid_mgr"
local util = {}
util.__index = util

local property_types = {
    color = "v4",
    v4 = "v4",
    m4 = "m4",
    texture = "s",
}

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

		if p then
			assert(property_types[p.type] == u.type)
			if p.type == "texture" then
				bgfx.set_texture(assert(p.stage), u.handle, p.handle)
			else				
				bgfx.set_uniform(u.handle, p.value)
			end
		else
			--log(string.format("uniform : %s, not privided, but shader program needed", name))
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

local function add_result(eid, group, materialinfo, properties, worldmat, result)
	local idx = result.cacheidx
	local r = result[idx]
	if r == nil then
		r = {}
		result[idx] = r
	end

	r.eid 		= eid
	r.mgroup 	= group

	r.material 	= materialinfo
	r.properties = properties
	r.worldmat 	= worldmat

	result.cacheidx = idx + 1
end

function util.insert_primitive(eid, meshhandle, materials, worldmat, filter)	
	local mgroups = meshhandle.groups
	for i=1, #mgroups do
		local g = mgroups[i]
		local mc = materials[i] or materials[1]

		local mi = mc.materialinfo
		local results = filter.result
		if mi.surface_type.transparency == "translucent" then
			add_result(eid, g, mi, mc.properties, worldmat, results.translucent)
		else
			add_result(eid, g, mi, mc.properties, worldmat, results.opaque)
		end

		if mi.surface_type.shadow.cast then
			add_result(eid, g, mi, mc.properties, worldmat, results.cast_shadow)
		end
	end
end

function util.create_render_queue_entity(world, viewsize, viewdir, eyepos, view_tag)
	local w, h = viewsize.w, viewsize.h
	return world:create_entity {
		viewport = {
			clear_state = {
				color = 0x303030ff,
				depth = 1,
				stencil = 0,
			},
			rect = {
				x = 0, y = 0,
				w = w, h = h,
			},
		},
		camera = {
			type = "",
			eyepos = eyepos,
			viewdir = viewdir,
			updir = {0, 1, 0, 0},
			frustum = {
				type = "mat",
				n = 0.1, f = 100000,
				fov = 60, aspect = w / h,
			},
		},
		viewid = viewidmgr.get(view_tag),
		render_target = {},	--default view
		primitive_filter = {
			view_tag = view_tag,
			filter_tag = "can_render",
			result = {
				case_shadow = {},
				translcuent = {},
				opaque = {}
			},
			render_properties = {
				lighting = {
					uniforms = {},
					textures = {},
				},
				shadow = {
					uniforms = {},
					textures = {},
				}
			}
		},
		main_camera = view_tag == "main_view" and true or nil,
	}
end

function util.default_sampler()
	return {
		U="MIRROR",
		V="MIRROR",
		W="MIRROR",
		MIN="LINEAR",
		MAG="LINEAR",
		MIP="LINEAR",
	}
end

function util.fill_default_sampler(sampler)
	local d = util.default_sampler()
	if sampler == nil then
		return d
	end

	for k, v in pairs(d) do
		if sampler[k] == nil then
			sampler[k] = v
		end
	end

	return sampler
end

local sample_types = {
	U="u", V="v", W="w", 
	MIN="-", MAG="+", MIP="*",

	RT = "r", 
	RT_READWRITE = "r", 
	RT_MSAA="r",

	BLIT = "b",
	BLIT_READBACK = "b", 
	BLIT_COMPUTE = "b",

	SAMPLE = "s",
}

local sample_value = {
	CLAMP="c", BORDER="b", MIRROR="",	--default
	POINT="p", ANISOTROPIC="a", LINEAR="", --default,

	-- RT
	RT_ON='t', 
	RT_READ="", RT_WRITE="w",
	RT_MSAA2="2", RT_MSAA4="4", RT_MSAA8="8", RT_MSAAX="x",

	-- BLIT
	BLIT_AS_DST = 'w', 
	BLIT_READBACK_ON = 'r',
	BLIT_COMPUTEREAD = '',
	BLIT_COMPUTEWRITE = 'c',	

	--SAMPLE
	SAMPLE_STENCIL='s', SAMPLE_DEPTH='d',
}

function util.generate_sampler_flag(sampler)
	if sampler == nil then
		return nil
	end
	local flag = ""	

	for k, v in pairs(sampler) do
		local value = sample_value[v]
		if value == nil then
			error("not support data, sample value : %s", v)
		end

		if #value ~= 0 then
			local type = sample_types[k]
			if type == nil then
				error("not support data, sample type : %s", k)
			end
			
			flag = flag .. type .. value
		end
	end

	return flag
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