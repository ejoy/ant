local ecs = ...
local world = ecs.world
local mc = import_package "ant.math".constant

local default_comp 	= import_package "ant.general".default
local setting		= import_package "ant.settings".setting

local bgfx 			= require "bgfx"
local viewidmgr 	= require "viewid_mgr"
local fbmgr			= require "framebuffer_mgr"
local samplerutil	= require "sampler"
local icamera		= world:interface "ant.camera|camera"

local wmt = ecs.transform "world_matrix_transform"
local function set_world_matrix(rc)
	bgfx.set_transform(rc.worldmat)
end

function wmt.process_entity(e)
	local rc = e._rendercache
	rc.set_transform = set_world_matrix
end

local irender		= ecs.interface "irender"
function irender.check_primitive_mode_state(state, template_state)
	local s = bgfx.parse_state(state)
	if s.PT then
		local ts = bgfx.parse_state(template_state)
		if s.PT ~= ts.PT then
			ts.PT = s.PT
			return bgfx.make_state(ts)
		end
	end
	return template_state
end

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

	if ib and ib.num ~= 0 then
		--TODO: need set function for set_index_buffer
		if type(ib.handle) == "number" then
			bgfx.set_index_buffer(ib.handle, ib.start, ib.num)
		else
			ib.handle:setI(ib.start, ib.num)
		end
	end

	local start_v, num_v = vb.start, vb.num
	if num_v ~= 0 then
		for idx, h in ipairs(vb.handles) do
			--TODO: need set function for set_index_buffer
			if type(h) == "number" then
				bgfx.set_vertex_buffer(idx-1, h, start_v, num_v)
			else
				h:setV(idx-1, start_v, num_v)
			end
		end
	end

	bgfx.submit(vid, ri.fx.prog, 0)
end

function irender.get_main_view_rendertexture()
	local mq = world:singleton_entity "main_queue"
	local fb = fbmgr.get(mq.render_target.fb_idx)
	return fbmgr.get_rb(fb[1]).handle
end

function irender.create_view_queue(view_rect, view_name, exclude)
	local mq = world:singleton_entity "main_queue"
	local rt = mq.render_target
	local cs = rt.clear_state
	return world:create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|view_queue",
			"ant.render|watch_screen_buffer",
			"ant.general|name",
		},
		data = {
			camera_eid = icamera.create{
				eyepos  = {0, 0, 0, 1},
				viewdir = {0, 0, 1, 0},
				frustum = default_comp.frustum(view_rect.w / view_rect.h),
				name = view_name,
			},

			primitive_filter = {
				filter_type = "visible",
				exclude_type = exclude
			},

			render_target = {
				viewid = viewidmgr.generate(view_name),
				view_mode = "s",
				clear_state = {
					color = cs.clear_color,
					depth = cs.clear_depth,
					stencil = cs.clear_stencil,
					clear = cs.clear,
				},
				view_rect = {
					x = view_rect.x or 0, y = view_rect.y or 0,
					w = view_rect.w or 1, h = view_rect.h or 1,
				},
				fb_idx = rt.fb_idx,
			},
			visible = true,
			name = view_name,
			view_queue = true,
			watch_screen_buffer = true,
		}
	}
end

function irender.create_orthoview_queue(view_rect, orthoface, queuename)
	local mq = world:singleton_entity "main_queue"
	local rt = mq.render_target
	local cs = rt.clear_state
	return world:create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|orthoview_queue",
			"ant.render|watch_screen_buffer",
			"ant.general|name",
		},
		data = {
			camera_eid = icamera.create {
				eyepos  = {0, 0, 0, 1},
				viewdir = {0, 0, 1, 0},
				updir = {0, 1, 0, 0},
				frustum = {
					l=-1, r=1, b=-1, t=1, n=0.25, f=250,
					ortho = true,
				},
				name = orthoface,
			},

			primitive_filter = {
				filter_type = "visible",
			},

			render_target = {
				viewid = viewidmgr.generate(orthoface),
				view_mode = "s",
				clear_state = {
					color = cs.clear_color,
					depth = cs.clear_depth,
					stencil = cs.clear_stencil,
					clear = cs.clear,
				},
				view_rect = {
					x = view_rect.x or 0, y = view_rect.y or 0,
					w = view_rect.w or 1, h = view_rect.h or 1,
				},
				fb_idx = rt.fb_idx,
			},
			visible = false,
			orthoview = orthoface,
			watch_screen_buffer = true,
			name = orthoface or queuename,
		}
	}
end

local rb_flag = samplerutil.sampler_flag {
	RT="RT_MSAA4",
	MIN="LINEAR",
	MAG="LINEAR",
	U="CLAMP",
	V="CLAMP",
}

function irender.create_pre_depth_queue(view_rect, camera_eid)
	local fbidx = fbmgr.create{
		fbmgr.create_rb{
			format = "R32F",
			w = view_rect.w, h=view_rect.h,
			layers = 1,
			flags = rb_flag,
		},
		fbmgr.create_rb{
			format = "D24S8",
			w = view_rect.w, h=view_rect.h,
			layers = 1,
			flags = rb_flag,
		}
	}

	return world:create_entity{
		policy = {
			"ant.render|render_queue",
			"ant.render|pre_depth_queue",
			"ant.render|watch_screen_buffer",
			"ant.general|name",
		},
		data = {
			name = "pre_z",
			camera_eid = camera_eid,
			primitive_filter = {
				filter_type = "visible",
			},
			render_target = {
				viewid = viewidmgr.get "depth",
				clear_state = {
					clear = "CD",
					color = 0,
					depth = 1,
				},
				view_mode = "s",
				view_rect = {
					x=view_rect.x or 0, y = view_rect.y or 0,
					w=view_rect.w, h=view_rect.h,
				},
				fb_idx = fbidx,
			},
			visible = true,
			pre_depth_queue = true,
			watch_screen_buffer = true,
		}
	}
end

function irender.create_main_queue(view_rect, camera_eid)
	local render_buffers = {}

	local sd = setting:data()
	local main_display_format = sd.graphic.hdr.enable and "RGBA16F" or "RGBA8"
	render_buffers[#render_buffers+1] = fbmgr.create_rb(
		default_comp.render_buffer(
		view_rect.w, view_rect.h, main_display_format, rb_flag)
	)

	local bloom = sd.graphic.postprocess.bloom
	if bloom.enable then
		render_buffers[#render_buffers+1] = fbmgr.create_rb(
			default_comp.render_buffer(
			view_rect.w, view_rect.h, main_display_format, rb_flag)
		)
	end

	local rs = sd.graphic.render

	local function get_depth_buffer()
		local pd = world:singleton_entity "pre_depth_queue"

		local pd_fb = fbmgr.get(pd.render_target.fb_idx)
		return pd_fb[#pd_fb]
	end

	render_buffers[#render_buffers+1] = get_depth_buffer()

	return world:create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|watch_screen_buffer",
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
					clear = "C",
				},
				view_rect = {
					x = view_rect.x or 0, y = view_rect.y or 0,
					w = view_rect.w or 1, h = view_rect.h or 1,
				},
				fb_idx = fbmgr.create(render_buffers),
			},
			primitive_filter = {
				filter_type = "visible",
			},
			visible = true,
			name = "main render queue",
			main_queue = true,
			watch_screen_buffer = true,
		}
	}
end

local blitviewid = viewidmgr.get "blit"
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
			"ant.render|watch_screen_buffer",
			"ant.general|name",
		},
		data = {
			camera_eid = cameraeid,
			render_target = {
				viewid = blitviewid,
				view_mode = "",
				clear_state = {
					clear = "",
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
			watch_screen_buffer = true,
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

--[[
	1 ---- 3
	|      |
	|      |
	0 ---- 2
]]

local function create_quad_ib(num_quad)
    local b = {}
    for ii=1, num_quad do
        local offset = (ii-1) * 4
        b[#b+1] = offset + 0
        b[#b+1] = offset + 1
        b[#b+1] = offset + 2

        b[#b+1] = offset + 1
        b[#b+1] = offset + 3
        b[#b+1] = offset + 2
    end

    return bgfx.create_index_buffer(bgfx.memory_buffer("w", b))
end

local quad_ib_num<const> = 512
local ibhandle = create_quad_ib(quad_ib_num)
function irender.quad_ib()
	return ibhandle
end

function irender.quad_ib_num()
	return quad_ib_num
end
