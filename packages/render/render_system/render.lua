local ecs = ...
local world = ecs.world
local w = world.w

local default_comp 	= import_package "ant.general".default
local setting		= import_package "ant.settings".setting
local settingdata 	= setting:data()
local graphic_setting=settingdata.graphic

local bgfx 			= require "bgfx"
local viewidmgr 	= require "viewid_mgr"
local fbmgr			= require "framebuffer_mgr"
local samplerutil	= require "sampler"

local function set_world_matrix(rc)
	bgfx.set_transform(rc.worldmat)
end

local function set_skinning_transform(rc)
	local sm = rc.skinning_matrices
	bgfx.set_multi_transforms(sm:pointer(), sm:count())
end

local world_trans_sys = ecs.system "world_transform_system"
function world_trans_sys:entity_init()
	for e in w:select "INIT render_object:in" do
		local ro = e.render_object
		if ro.skinning_matrices == nil then
			e.render_object.set_transform = set_world_matrix
		else
			e.render_object.set_transform = set_skinning_transform
		end
	end
end

local LAYER_NAMES<const> = {"foreground", "opacity", "background", "translucent", "decal", "ui"}

local QUEUE_TYPES <const> = {
    main_queue = LAYER_NAMES,
    blit_queue = {"opacity",},
    pre_depth_queue = {"opacity"},
}

local irender		= ecs.interface "irender"

function irender.layer_names()
	return LAYER_NAMES
end

function irender.check_primitive_mode_state(state, template_state)
	local s = bgfx.parse_state(state)
	local ts = bgfx.parse_state(template_state)
	ts.PT = s.PT
	ts.CULL = s.CULL
	return bgfx.make_state(ts)
end

function irender.draw(vid, ri, mat)
	ri:set_transform()

	local _mat = mat or ri

	bgfx.set_state(_mat.state)
	bgfx.set_stencil(_mat.stencil)
	local properties = _mat.properties
	if properties then
		for n, p in pairs(properties) do
			p:set()
		end
	end
	local ib, vb = ri.ib, ri.vb

	if ib and ib.num ~= 0 then
		bgfx.set_index_buffer(ib.handle, ib.start, ib.num)
	end

	local start_v, num_v = vb.start, vb.num
	if num_v ~= 0 then
		bgfx.set_vertex_buffer(vb.handles, start_v, num_v)
	end

	bgfx.submit(vid, _mat.fx.prog, 0)
end

function irender.get_main_view_rendertexture()
	local mq = w:singleton("main_queue", "render_target:in")
	local fb = fbmgr.get(mq.render_target.fb_idx)
	return fbmgr.get_rb(fb[1]).handle
end

local default_clear_state<const> = {
	color = graphic_setting.render.clear_color or 0x000000ff,
	depth = 1.0,
	clear = "CD",
}

function irender.create_view_queue(view_rect, view_queuename, camera_ref, filtertype, exclude, surfacetypes, visible)
	surfacetypes = surfacetypes or QUEUE_TYPES["main_queue"]
	filtertype = filtertype or "main_view"
	w:register{name = view_queuename}

	local fbidx = fbmgr.get_fb_idx(viewidmgr.get "main_view")
	ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|watch_screen_buffer",
			"ant.general|name",
		},
		data = {
			camera_ref = assert(camera_ref),
			render_target = {
				viewid		= viewidmgr.generate(view_queuename),
				view_mode 	= "s",
				clear_state	= default_clear_state,
				view_rect	= view_rect,
				fb_idx		= fbidx,
			},
			[view_queuename]	= true,
			name 				= view_queuename,
			queue_name			= view_queuename,
			primitive_filter	= {
				filter_type = filtertype,
				exclude_type = exclude,
				table.unpack(surfacetypes),
			},
			cull_tag			= {},
			visible 			= visible or false,
			watch_screen_buffer	= true,
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

function irender.create_pre_depth_queue(vr, camera_ref)
	local depth_viewid = viewidmgr.get "depth"
	local fbidx = fbmgr.create{
		fbmgr.create_rb{
			format = "R32F",
			w = vr.w, h=vr.h,
			layers = 1,
			flags = rb_flag,
		},
		fbmgr.create_rb{
			format = "D24S8",
			w = vr.w, h=vr.h,
			layers = 1,
			flags = rb_flag,
		}
	}

	fbmgr.bind(depth_viewid, fbidx)

	ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|pre_depth_queue",
			"ant.render|watch_screen_buffer",
			"ant.render|cull",
			"ant.general|name",
		},
		data = {
			camera_ref = camera_ref,
			render_target = {
				viewid = depth_viewid,
				clear_state = {
					clear = "CD",
					color = 0,
					depth = 1,
				},
				view_mode = "s",
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
				fb_idx = fbidx,
			},
			primitive_filter = {
				filter_type = "main_view",
				table.unpack(QUEUE_TYPES["pre_depth_queue"]),
			},
			cull_tag 		= {},
			queue_name 		= "pre_depth_queue",
			name 			= "pre_depth_queue",
			visible 		= true,
			pre_depth_queue = true,
			watch_screen_buffer = true,
			INIT			= true,
		}
	}
end

local function create_main_fb(fbsize)
	local render_buffers = {}
	render_buffers[#render_buffers+1] = fbmgr.create_rb(
		default_comp.render_buffer(
			fbsize.w, fbsize.h, "RGBA16F", rb_flag)
	)

	if graphic_setting.postprocess.bloom.enable then
		render_buffers[#render_buffers+1] = fbmgr.create_rb(
			default_comp.render_buffer(
				fbsize.w, fbsize.h, "RGBA16F", rb_flag)
		)
	end

	local function get_depth_buffer()
		if not graphic_setting.disable_pre_z then
			local depth_viewid = viewidmgr.get "depth"
			local depthfb = fbmgr.get_byviewid(depth_viewid)
			return depthfb[2]
		end
		return fbmgr.create_rb(
			default_comp.render_buffer(
				fbsize.w, fbsize.h, "D24S8", rb_flag)
		)
	end

	render_buffers[#render_buffers+1] = get_depth_buffer()
	local fb = fbmgr.create(render_buffers)

	print("main queue fb 1:", 0xffff&fbmgr.get_rb(1).handle)
	print("main queue fb 2:", 0xffff&fbmgr.get_rb(2).handle)
	return fb
end

function irender.create_main_queue(vr, camera_ref)
	local fbidx = create_main_fb(vr)
	ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|watch_screen_buffer",
			"ant.render|main_queue",
			"ant.render|cull",
			"ant.general|name",
		},
		data = {
			name = "main_queue",
			camera_ref = camera_ref,
			render_target = {
				viewid = viewidmgr.get "main_view",
				view_mode = "s",
				clear_state = default_clear_state,
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
				fb_idx = fbidx,
			},
			primitive_filter = {
				filter_type = "main_view",
				table.unpack(QUEUE_TYPES["main_queue"]),
			},
			cull_tag = {},
			visible = true,
			INIT = true,
			main_queue = true,
			watch_screen_buffer = true,
			queue_name = "main_queue",
		}
	}
end

function irender.set_view_frame_buffer(viewid, fbidx)
	local fb = fbmgr.get(fbidx)
	if fb then
		bgfx.set_view_frame_buffer(viewid, fb.handle)
	end
end

function irender.screen_capture(force_read)
	for e in w:select "main_queue render_target:in" do
		local fbidx = e.render_target.fb_idx
		local fb = fbmgr.get(fbidx)
		local s = setting:data()
		local format = s.graphic.hdr.enable and s.graphic.hdr.format or "RGBA8"
		local handle, width, height, pitch = irender.read_render_buffer_content(format, fb[1], force_read)
		return width, height, pitch, tostring(handle)
	end
end

function irender.is_msaa_buffer(rbidx)
	local rb = fbmgr.get_rb(rbidx)
	return rb.flags:match "r[248x]" ~= nil
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
			BLIT="BLIT_READWRITE",
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

local quad_ib_num<const> = 2048
local ibhandle = create_quad_ib(quad_ib_num)
function irender.quad_ib()
	return ibhandle
end

function irender.quad_ib_num()
	return quad_ib_num
end
