local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

local bgfx 			= require "bgfx"
local viewidmgr 	= require "viewid_mgr"
local fbmgr			= require "framebuffer_mgr"
local camerautil	= require "camera.util"
local default_comp 	= require "components.default"
local computil 		= require "components.util"

local fs 			= require "filesystem"
local mathbaselib 	= require "math3d.baselib"

local setting		= require "setting"

local util = {}
util.__index = util

local property_types = {
    color = "v4",
    v4 = "v4",
    m4 = "m4",
    texture = "s",
}

local function update_properties(material, properties, render_properties)
	local su = material.fx.shader.uniforms
	for name, u in pairs(su) do
		local function find_property(name, properties)
			if properties == nil then
				return nil
			end

			local uniforms = properties.uniforms
			if uniforms then
				local p = uniforms[name]
				if p then
					return p
				end
			end
			local textures = properties.textures
			if textures then
				local tex = textures[name]
				if tex then
					if tex.ref_path then
						local texkey = assert(tex.ref_path)
						tex.handle = assetmgr.get_resource(texkey).handle	--set texture handle every time
					else
						assert(tex.handle)
					end
				end
				return tex
			end
		end

		local p = find_property(name, properties)
		if p == nil then
			p = find_property(name, material.properties)

			if p == nil then
				for _, rp in pairs(render_properties) do
					p = find_property(name, rp)
					if p then
						break
					end
				end
			end
		end

		if p then
			assert(property_types[p.type] == u.type)
			if p.type == "texture" then
				bgfx.set_texture(assert(p.stage), u.handle, p.handle)
			else
				bgfx.set_uniform(u.handle, p.value)
			end
		else
			--log,info(string.format("uniform : %s, not privided, but shader program needed", name))
		end
	end
end

function util.draw_primitive(vid, primgroup, mat, render_properties)
    bgfx.set_transform(mat)

	local material = primgroup.material
	bgfx.set_state(bgfx.make_state(material.state)) -- always convert to state str
	update_properties(material, primgroup.properties, render_properties)

	local prog = material.fx.shader.prog

	local mg = assert(primgroup.mgroup)
	local ib, vb = mg.ib, mg.vb	

	if ib then
		bgfx.set_index_buffer(ib.handle, ib.start, ib.num)
	end

	local start_v, num_v = vb.start, vb.num
	for idx, v in ipairs(vb.handles) do
		local handle = v.handle
		bgfx.set_vertex_buffer(idx-1, handle, start_v, num_v)
	end
	bgfx.submit(vid, prog, 0, false)
end

local function add_tranformed_bounding(r, worldmat, bounding)
	if bounding then
		local tb = r.tb	-- transformed bounding
		if tb == nil then
			tb = mathbaselib.new_bounding(ms)
			r.tb = tb
		end
		tb:reset(bounding, worldmat)
	else
		r.tb = nil
	end
end

local function add_result(eid, group, materialinfo, properties, worldmat, result)
	local idx = result.cacheidx
	local r = result[idx]
	if r == nil then
		r = {
			mgroup 		= group,
			material 	= assert(materialinfo),
			properties 	= properties,
			worldmat 	= worldmat,
			eid 		= eid,
		}
		result[idx] = r
	else
		r.mgroup 	= group
		r.material 	= assert(materialinfo)
		r.properties= properties
		r.worldmat 	= worldmat
		r.eid 		= eid
	end

	add_tranformed_bounding(r, worldmat, group.bounding)
	result.cacheidx = idx + 1
	return r
end

function util.insert_primitive(eid, group, material, worldmat, filter)
	local refkey = material.ref_path
	local mi = assert(assetmgr.get_resource(refkey))
	local resulttarget = assert(filter.result[mi.fx.surface_type.transparency])
	add_result(eid, group, mi, material.properties, worldmat, resulttarget)
end

function util.create_main_queue(world, view_rect, viewdir, eyepos)
	local rb_flag = util.generate_sampler_flag {
		RT="RT_MSAA2",
		MIN="LINEAR",
		MAG="LINEAR",
		U="CLAMP",
		V="CLAMP"
	}

	assert(world:first_entity "camera_mgr" == nil, "camera_mgr entity have been created")

	camerautil.create_camera_mgr_entity(world, 
		default_comp.camera(eyepos, viewdir, 
			default_comp.frustum(view_rect.w, view_rect.h)))

	local sd = setting.get()

	local render_buffers = {}

	local main_display_format = sd.graphic.hdr.enable and "RGBA16F" or "RGBA8"
	render_buffers[#render_buffers+1] = fbmgr.create_rb(
		default_comp.render_buffer(
		view_rect.w, view_rect.h, main_display_format, rb_flag)
	)

	local bloom = sd.graphic.postprocess.bloom
	if bloom.enable then
		local fmt = bloom.format
		-- not support RGBA8
		assert(fmt == "RGBA16F" or fmt == "RGBA32F")
		render_buffers[#render_buffers+1] = fbmgr.create_rb(
			default_comp.render_buffer(
			view_rect.w, view_rect.h, bloom.format, rb_flag)
		)
	end
	render_buffers[#render_buffers+1] = fbmgr.create_rb(
		default_comp.render_buffer(
		view_rect.w, view_rect.h, "D24S8", rb_flag)
	)

	return world:create_entity {
		camera_tag = "main_view",
		viewid = viewidmgr.get "main_view",
		render_target = {
			viewport = default_comp.viewport(view_rect),
			fb_idx = fbmgr.create {
				render_buffers = render_buffers
			},
		},
		primitive_filter = {
			filter_tag = "can_render",
		},
		main_queue = true,
		visible = true,
	}
end

function util.default_sampler()
	return {
		U="WRAP",
		V="WRAP",
		W="WRAP",
		MIN="LINEAR",
		MAG="LINEAR",
		MIP="POINT",
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

	COMPARE="c",
	BOARD_COLOR="c",

	RT = "r", 
	RT_READWRITE = "r", 
	RT_MSAA="r",

	BLIT = "b",
	BLIT_READBACK = "b", 
	BLIT_COMPUTE = "b",

	SAMPLE = "s",
}

local sample_value = {
	-- filter mode
	CLAMP="c", MIRROR = "m", BORDER="b", WRAP="w",	--default
	-- filter address
	POINT="p", ANISOTROPIC="a", LINEAR="l", --default,

	-- compare
	COMPARE_LESS = '<',
	COMPARE_LEQUAL = '[',
	COMPARE_EQUAL = '=',
	COMPARE_GEQUAL = ']',
	COMPARE_GREATER = '>',
	COMPARE_NOTEQUAL = '!',
	COMPARE_NEVER = '-',
	COMPARE_ALWAYS = '+',

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
		if k == "BOARD_COLOR" then
			flag = flag .. sample_types[k] .. v
		else
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
	end

	return flag
end

local blitviewid = viewidmgr.get "blit"

function util.get_main_view_rendertexture(world)
	local mq = world:first_entity "main_queue"
	local fb = fbmgr.get(mq.render_target.fb_idx)
	return fbmgr.get_rb(fb[1]).handle
end

function util.create_blit_queue(world, viewrect)
	camerautil.bind_camera(world, "blit_view",
		default_comp.camera(nil, nil, default_comp.frustum(viewrect.w, viewrect.h))
	)

	world:create_entity {
		camera_tag = "blit_view",
		viewid = blitviewid,
		render_target = {
			viewport = default_comp.viewport(viewrect),
		},
		primitive_filter = {
			filter_tag = "blit_render",
		},
		visible = true,
	}
	local eid = computil.create_quad_entity(world, viewrect,
	fs.path "/pkg/ant.resources/depiction/materials/fullscreen.material", nil, "full_quad")
	world:remove_component(eid, "can_render")
	world:add_component(eid, "blit_render", true)
end

function util.modify_view_rect(world,rect)
	for _,eid in world:each("render_target") do
		local e = world[eid]
		world:add_component_child(
			e["render_target"]["viewport"],
			"rect",
			"rect",
			rect)
	end
end

local statemap = {
	all 			= "CDS",
	color 			= "C",
	depth 			= "D",
	stencil 		= "S",
	colordepth 		= "CD",
	colorstencil	= "CD",
	depthstencil 	= "DS",
	C 				= "C",
	D 				= "D",
	S				= "S",
	CD 				= "CD",
	CS 				= "CS",
	DS 				= "DS",
}

function util.update_frame_buffer_view(viewid, fbidx)
	local fb = fbmgr.get(fbidx)
	if fb then
		bgfx.set_view_frame_buffer(viewid, fb.handle)
	end
end

function util.update_viewport(viewid, viewport)
	local cs = viewport.clear_state
	local clear_what = cs.clear
	local state = statemap[clear_what]
	if state then
		bgfx.set_view_clear(viewid, state, cs.color, cs.depth, cs.stencil)
	end

	local rt = viewport.rect
	bgfx.set_view_rect(viewid, rt.x, rt.y, rt.w, rt.h)
end

function util.update_render_target(viewid, rt)
	util.update_frame_buffer_view(viewid, rt.fb_idx)
	util.update_viewport(viewid, rt.viewport)
end

return util