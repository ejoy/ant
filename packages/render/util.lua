local assetpkg = import_package "ant.asset"
local assetmgr = assetpkg.mgr

local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local mu = mathpkg.util
local math3d = require "math3d"

local bgfx 			= require "bgfx"
local viewidmgr 	= require "viewid_mgr"
local fbmgr			= require "framebuffer_mgr"
local camerautil	= require "camera.util"
local default_comp 	= require "components.default"
local computil 		= require "components.util"

local fs 			= require "filesystem"

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

function util.create_main_queue(world, view_rect)
	local rb_flag = util.generate_sampler_flag {
		RT="RT_MSAA2",
		MIN="LINEAR",
		MAG="LINEAR",
		U="CLAMP",
		V="CLAMP"
	}

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
		policy = {
			"ant.render|render_queue",
			"ant.render|main_queue",
			"ant.render|name",
		},
		data = {
			camera_eid = 0,
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
			visible = true,
			name = "main render queue",
			main_queue = true,
		}
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
	local mq = world:singleton_entity "main_queue"
	local fb = fbmgr.get(mq.render_target.fb_idx)
	return fbmgr.get_rb(fb[1]).handle
end

function util.create_blit_queue(world, viewrect)
	local cameraeid = world:create_entity {
		policy = {
			"ant.render|camera",
			"ant.render|name",
		},
		data = {
			camera = {
				eyepos = mc.T_ZERO_PT,
				viewdir = mc.T_ZAXIS,
				updir = mc.T_YAXIS,
				frustum = default_comp.frustum(viewrect.w, viewrect.h),
			},
			name = "blit_camera",
		}
	}

	world:create_entity {
		policy = {
			"ant.render|blit_queue",
			"ant.render|render_queue",
			"ant.render|name",
		},
		data = {
			camera_eid = cameraeid,
			viewid = blitviewid,
			render_target = {
				viewport = default_comp.viewport(viewrect),
			},
			primitive_filter = {
				filter_tag = "blit_render",
			},
			visible = true,
			blit_queue = true,
			name = "blit main queue to window frame buffer",
		}
	}

	local eid = world:create_entity {
		policy = {
			"ant.render|name",
			"ant.render|blitrender",
		},
		data = {
			transform = {srt = mu.srt()},
			rendermesh = {},
			material = {ref_path = fs.path "/pkg/ant.resources/depiction/materials/fullscreen.material"},
			blit_render = true,
			name = "full_quad",
		}
	}

	world[eid].rendermesh.reskey = assetmgr.register_resource(
		fs.path "//res.mesh/quad.mesh",
		computil.quad_mesh())
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

function util.screen_capture(world, force_read)
	local mq = world:singleton_entity "main_queue"
	local fbidx = mq.render_target.fb_idx
	local fb = fbmgr.get(fbidx)
	local s = setting.get()
	local format = s.graphic.hdr.enable and s.graphic.hdr.format or "RGBA8"
	local handle, width, height, pitch = util.read_render_buffer_content(format, fb[1], force_read)
	return width, height, pitch, tostring(handle)
end

function util.read_render_buffer_content(format, rb_idx, force_read, size)
	local rb = fbmgr.get_rb(rb_idx)
	local w, h
	if size then
		w, h = size.w, size.h
	else
		w, h = rb.w, rb.h
	end

	local elem_size_mapper = {
		RGBA8 = 4,
		RGBA16F = 8,
	}

	local elem_size = assert(elem_size_mapper[format])

	local memory_handle = bgfx.memory_texture(w * h * elem_size)
	local rb_handle = fbmgr.get_rb(fbmgr.create_rb {
		w = w,
		h = h,
		layers = 1,
		format = format,
		flags = util.generate_sampler_flag {
			BLIT="BLIT_AS_DST",
			BLIT_READBACK="BLIT_READBACK_ON",
			MIN="POINT",
			MAG="POINT",
			U="CLAMP",
			V="CLAMP",
		}
	}).handle

	local viewid = viewidmgr.get "blit"
	if viewid == nil then
		viewid = viewidmgr.generate "blit"
	end
	bgfx.blit(viewid, rb_handle, 0, 0, rb.handle)
	bgfx.read_texture(rb_handle, memory_handle)

	if force_read then
		bgfx.frame()
		bgfx.frame()
	end

	return memory_handle, size.w, size.h, size.w * elem_size
end

return util