local ecs = ...
local world = ecs.world
local mc = import_package "ant.math".constant

local default_comp 	= import_package "ant.general".default

local bgfx 			= require "bgfx"
local viewidmgr 	= require "viewid_mgr"
local fbmgr			= require "framebuffer_mgr"
local samplerutil	= require "sampler"

local setting		= require "setting"

local irender = ecs.interface "irender"

local vpt = ecs.transform "visible_primitive_transform"
function vpt.process_entity(e)
	local f = e.primitive_filter
	f.insert_item = function (filter, fxtype, eid, rc)
		filter.result[fxtype].items[eid] = rc
	end
end

local icamera = world:interface "ant.camera|camera"
function irender.draw(vid, ri)
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

function irender.get_main_view_rendertexture()
	local mq = world:singleton_entity "main_queue"
	local fb = fbmgr.get(mq.render_target.fb_idx)
	return fbmgr.get_rb(fb[1]).handle
end

function irender.create_main_queue(view_rect)
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

	local camera_eid = icamera.create{
		eyepos  = {0, 0, 0, 1},
		viewdir = {0, 0, 1, 0},
		frustum = default_comp.frustum(view_rect.w / view_rect.h),
        name = "default_camera",
	}

	local rs = sd.graphic.render

	return world:create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|main_queue",
			"ant.general|name",
		},
		data = {
			camera_eid = camera_eid,
			
			render_target = {
				viewid = viewidmgr.get "main_view",
				view_mode = "s",
				clear_state = {
					color = rs.clear_color or 0x000000ff,
					depth = rs.clear_depth or 1,
					stencil = rs.clear_stencil or 0,
					clear = rs.clear or "CDS",
				},
				view_rect = {
					x = view_rect.x or 0, y = view_rect.y or 0,
					w = view_rect.w or 1, h = view_rect.h or 1,
				},
				fb_idx = fbmgr.create {
					render_buffers = render_buffers
				},
			},
			primitive_filter = {
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
function irender.create_blit_queue(viewrect)
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
			render_target = {
				viewid = blitviewid,
				view_mode = "",
				clear_state = {
					color = 0x000000ff,
					depth = 1,
					stencil = 0,
					clear = "C",
				},
				view_rect = {
					x = viewrect.x or 0, y = viewrect.y or 0,
					w = viewrect.w or 1, h = viewrect.h or 1,
				},
			},
			primitive_filter = {
				filter_type = "blit_view",
			},
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
			material = "/pkg/ant.resources/materials/fullscreen.material",
			state = ies.create_state "blit_view",
			name = "full_quad",
			scene_entity = true,
			mesh = world:interface "ant.render|entity".fullquad_mesh(),
		}
	}
end

function irender.set_view_frame_buffer(viewid, fbidx)
	local fb = fbmgr.get(fbidx)
	if fb then
		bgfx.set_view_frame_buffer(viewid, fb.handle)
	end
end

function irender.screen_capture(world, force_read)
	local mq = world:singleton_entity "main_queue"
	local fbidx = mq.render_target.fb_idx
	local fb = fbmgr.get(fbidx)
	local s = setting:data()
	local format = s.graphic.hdr.enable and s.graphic.hdr.format or "RGBA8"
	local handle, width, height, pitch = irender.read_render_buffer_content(format, fb[1], force_read)
	return width, height, pitch, tostring(handle)
end

function irender.read_render_buffer_content(format, rb_idx, force_read, size)
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

local irq = ecs.interface "irenderqueue"

function irq.clear_state(eid)
	return world[eid].render_target.clear_state
end

function irq.view_rect(eid)
	return world[eid].render_target.view_rect
end

function irq.frame_buffer(eid)
	return world[eid].render_target.fb_idx
end

function irq.camera(eid)
	return world[eid].camera_eid
end

function irq.visible(eid)
	return world[eid].visible
end

function irq.main_camera()
	return irq.camera(world:singleton_entity_id "main_queue")
end

local function view_clear(viewid, cs)
	bgfx.set_view_clear(viewid, cs.clear, cs.color, cs.depth, cs.stencil)
	world:pub{"component_changed", "target_clear"}
end

function irq.set_view_clear_state(eid, state)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.clear = state
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_color(eid, color)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.color = color
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_depth(eid, depth)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.depth = depth
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear_stencil(eid, stencil)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.stencil = stencil
	view_clear(rt.viewid, cs)
end

function irq.set_view_clear(eid, what, color, depth, stencil)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.color = color
	cs.depth = depth
	cs.stencil = stencil

	cs.clear = what
	bgfx.set_view_clear(rt.viewid, what, color, depth, stencil)
	world:pub{"component_changed", "target_clear"}
end

function irq.set_view_rect(eid, rect)
	local rt = world[eid].render_target
	local vr = rt.view_rect
	vr.x, vr.y = rect.x, rect.y
	vr.w, vr.h = rect.w, rect.h
	bgfx.set_view_rect(rt.viewid, vr.x, vr.y, vr.w, vr.h)
	world:pub{"component_changed", "viewport"}
end

function irq.set_frame_buffer(eid, fbidx)
	local rt = world[eid].render_target
	rt.fb_idx = fbidx
	world:pub{"component_changed", "framebuffer"}
end

function irq.set_camera(eid, cameraeid)
	world[eid].camera_eid = cameraeid
	world:pub{"component_changed", "camera_eid"}
end

function irq.set_visible(eid, visible)
	local q = world[eid]
	q.visible = visible

	world:pub{"component_changed", "visible"}
end

function irq.update_rendertarget(rt)
	local viewid = rt.viewid
	bgfx.set_view_mode(viewid, rt.view_mode)
	local vr = rt.view_rect
	bgfx.set_view_rect(viewid, vr.x, vr.y, vr.w, vr.h)
	local cs = rt.clear_state
	bgfx.set_view_clear(viewid, cs.clear, cs.color, cs.depth, cs.stencil)
	
	local fb_idx = rt.fb_idx
	if fb_idx then
		fbmgr.bind(viewid, fb_idx)
	else
		rt.fb_idx = fbmgr.get_fb_idx(viewid)
	end
end