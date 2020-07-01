local ecs = ...
local world = ecs.world
local mc = import_package "ant.math".constant

local default_comp 	= import_package "ant.general".default

local bgfx 			= require "bgfx"
local viewidmgr 	= require "viewid_mgr"
local fbmgr			= require "framebuffer_mgr"
local samplerutil	= require "sampler"

local setting		= require "setting"

local irender_class = ecs.interface "irender"
local irender = world:interface "ant.render|irender"
function irender_class.draw(vid, ri)
	ri:set_transform()

	bgfx.set_state(ri.state)
	local properties = ri.properties
	if properties then
		for n, p in pairs(properties) do
			p:set()
		end
	end
	local ib, vb = ri.ib, ri.vb

	if ib then
		bgfx.set_index_buffer(ib.handle, ib.start, ib.num)
	end
	local start_v, num_v = vb.start, vb.num
	for idx, h in ipairs(vb.handles) do
		bgfx.set_vertex_buffer(idx-1, h, start_v, num_v)
	end
	bgfx.submit(vid, ri.fx.prog, 0)
end

function irender_class.get_main_view_rendertexture()
	local mq = world:singleton_entity "main_queue"
	local fb = fbmgr.get(mq.render_target.fb_idx)
	return fbmgr.get_rb(fb[1]).handle
end

function irender_class.create_main_queue(view_rect)
	local rb_flag = samplerutil.sampler_flag {
		RT="RT_MSAA2",
		MIN="LINEAR",
		MAG="LINEAR",
		U="CLAMP",
		V="CLAMP"
	}

	local sd = setting:data()
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
			view_rect.w, view_rect.h, fmt, rb_flag)
		)
	end
	render_buffers[#render_buffers+1] = fbmgr.create_rb(
		default_comp.render_buffer(
		view_rect.w, view_rect.h, "D24S8", rb_flag)
	)

	local icamera = world:interface "ant.camera|camera"
	local camera_eid = icamera.create{
		eyepos  = {0, 0, 0, 1},
		viewdir = {0, 0, 1, 0},
		frustum = default_comp.frustum(view_rect.w / view_rect.h),
        name = "default_camera",
	}

	return world:create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|main_queue",
			"ant.general|name",
		},
		data = {
			camera_eid = camera_eid,
			
			render_target = world.component "render_target" {
				viewid = viewidmgr.get "main_view",
				view_mode = "s",
				viewport = default_comp.viewport(view_rect),
				fb_idx = fbmgr.create {
					render_buffers = render_buffers
				},
			},
			primitive_filter = world.component "primitive_filter" {
				filter_type = "visible",
			},
			visible = true,
			name = "main render queue",
			main_queue = true,
		}
	}
end

local blitviewid = viewidmgr.get "blit"
local icamera = world:interface "ant.camera|camera"
function irender_class.create_blit_queue(viewrect)
	local cameraeid = icamera.create {
		eyepos = mc.ZERO_PT,
		viewdir = mc.ZAXIS,
		updir = mc.YAXIS,
		frustum = default_comp.frustum(viewrect.w / viewrect.h),
		name = "blit_camera",
	}

	world:create_entity {
		policy = {
			"ant.render|blit_queue",
			"ant.render|render_queue",
			"ant.general|name",
		},
		data = {
			camera_eid = cameraeid,
			render_target = world.component "render_target" {
				viewid = blitviewid,
				viewport = default_comp.viewport(viewrect),
			},
			primitive_filter = world.component "primitive_filter" {
				filter_type = "blit_view",
			},
			view_mode = "",
			visible = true,
			blit_queue = true,
			name = "blit main queue to window frame buffer",
		}
	}

	local ies = world:interface "ant.scene|ientity_state"
	world:create_entity {
		policy = {
			"ant.general|name",
			"ant.render|render",
		},
		data = {
			transform = {},
			material = world.component "resource" "/pkg/ant.resources/materials/fullscreen.material",
			state = ies.create_state "blit_view",
			name = "full_quad",
			scene_entity = true,
			mesh = world:interface "ant.render|entity".fullquad_mesh(),
		}
	}
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

function irender_class.update_frame_buffer_view(viewid, fbidx)
	local fb = fbmgr.get(fbidx)
	if fb then
		bgfx.set_view_frame_buffer(viewid, fb.handle)
	end
end

function irender_class.update_viewport(viewid, viewport)
	local cs = viewport.clear_state
	local clear_what = cs.clear
	local state = statemap[clear_what]
	if state then
		bgfx.set_view_clear(viewid, state, cs.color, cs.depth, cs.stencil)
	end

	local rt = viewport.rect
	bgfx.set_view_rect(viewid, rt.x, rt.y, rt.w, rt.h)
end

function irender_class.update_render_target(viewid, rt)
	irender.update_frame_buffer_view(viewid, rt.fb_idx)
	irender.update_viewport(viewid, rt.viewport)
end

function irender_class.screen_capture(world, force_read)
	local mq = world:singleton_entity "main_queue"
	local fbidx = mq.render_target.fb_idx
	local fb = fbmgr.get(fbidx)
	local s = setting:data()
	local format = s.graphic.hdr.enable and s.graphic.hdr.format or "RGBA8"
	local handle, width, height, pitch = irender.read_render_buffer_content(format, fb[1], force_read)
	return width, height, pitch, tostring(handle)
end

function irender_class.read_render_buffer_content(format, rb_idx, force_read, size)
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
		flags = samplerutil.sampler_flag {
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