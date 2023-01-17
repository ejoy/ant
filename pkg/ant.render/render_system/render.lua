local ecs = ...
local world = ecs.world
local w = world.w

local default_comp 	= import_package "ant.general".default
local setting		= import_package "ant.settings".setting
local ENABLE_PRE_DEPTH<const> = not setting:get "graphic/disable_pre_z"
local ENABLE_FXAA<const> = setting:get "graphic/postprocess/fxaa/enable"

local bgfx 			= require "bgfx"
local viewidmgr 	= require "viewid_mgr"
local fbmgr			= require "framebuffer_mgr"
local declmgr		= require "vertexdecl_mgr"
local sampler		= require "sampler"
local rendercore	= ecs.clibs "render.core"

local LAYER_NAMES<const> = {"foreground", "opacity", "background", "translucent", "decal_stage", "ui_stage"}

local irender		= ecs.interface "irender"

function irender.use_pre_depth()
	return ENABLE_PRE_DEPTH
end

function irender.layer_names()
	return LAYER_NAMES
end

local function def_state_op(dst_s, src_s)
	dst_s.PT           = src_s.PT
	dst_s.CULL         = src_s.CULL
	dst_s.DEPTH_TEST   = "GREATER"
end

function irender.create_material_from_template(template_material_obj, state, cache)
	local mo = cache[template_material_obj]
	if nil == mo then
		mo = {}
		cache[template_material_obj] = mo
	end

	local m = mo[state]
	if nil == m then
		m = template_material_obj:copy(state)
		mo[state] = m
	end

	return m
end

function irender.check_set_state(dst_m, src_m, state_op)
	local t_dst_s = bgfx.parse_state(dst_m:get_state())
	local t_src_s = bgfx.parse_state(src_m:get_state())
	state_op = state_op or def_state_op
	state_op(t_dst_s, t_src_s)
	return bgfx.make_state(t_dst_s)
end

local MATERIAL_INDICES<const> = {
	main_queue		= 0,
	pre_depth_queue	= 1,
	pickup_queue	= 2,
	csm1_queue		= 3,
	csm2_queue		= 3,
	csm3_queue		= 3,
	csm4_queue		= 3,
	bake_lightmap_queue = 4,
}

function irender.material_index(queue_name)
	return MATERIAL_INDICES[queue_name]
end

function irender.draw(viewid, drawer_tag, queuename)
	local tagid = w:component_id(drawer_tag)
	local qn = queuename or ""
	rendercore.draw(tagid, viewid, MATERIAL_INDICES[qn] or 0)
end

function irender.get_main_view_rendertexture()
	local mq = w:first("main_queue render_target:in")
	return fbmgr.get_rb(mq.render_target.fb_idx, 1).handle
end

local default_clear_state = {
	color = setting:data().graphic.render.clear_color or 0x000000ff,
	depth = 0.0,
	clear = "CD",
}

if ENABLE_PRE_DEPTH then
	default_clear_state.depth = nil
	default_clear_state.clear = "C"
end

function irender.create_view_queue(view_rect, view_queuename, camera_ref, filtertype, exclude, visible)
	filtertype = filtertype or "main_view"

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
				viewid		= viewidmgr.get(view_queuename),
				view_mode 	= "s",
				clear_state	= default_clear_state,
				view_rect	= {x=view_rect.x, y=view_rect.y, w=view_rect.w, h=view_rect.h, ratio=view_rect.ratio},
				fb_idx		= fbidx,
			},
			[view_queuename]	= true,
			name 				= view_queuename,
			queue_name			= view_queuename,
			primitive_filter	= {
				filter_type = filtertype,
				exclude_type = exclude,
			},
			visible 			= visible or false,
			watch_screen_buffer	= true,
		}
	}
end

local function create_depth_rb(ww, hh)
	return fbmgr.create_rb{
		format = "D16F",
		w = ww, h = hh,
		layers = 1,
		flags = sampler {
			RT = ENABLE_FXAA and "RT_ON" or "RT_MSAA4|RT_WRITE",
			MIN="LINEAR",
			MAG="LINEAR",
			U="CLAMP",
			V="CLAMP",
		},
	}
end

function irender.create_pre_depth_queue(vr, camera_ref)
	local depth_viewid = viewidmgr.get "pre_depth"
	local fbidx = fbmgr.create{rbidx = create_depth_rb(vr.w, vr.h)}

	fbmgr.bind(depth_viewid, fbidx)

	ecs.create_entity {
		policy = {
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
					clear = "D",
					depth = 0,
				},
				view_mode = "s",
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h, ratio=vr.ratio},
				fb_idx = fbidx,
			},
			primitive_filter = {
				filter_type = "main_view",
				"opacity",
			},
			queue_name 		= "pre_depth_queue",
			name 			= "pre_depth_queue",
			visible 		= true,
			pre_depth_queue = true,
			watch_screen_buffer = true,
		}
	}
end

local function create_main_fb(fbsize)
	local function get_depth_buffer()
		if ENABLE_PRE_DEPTH then
			local depth_viewid = viewidmgr.get "pre_depth"
			local depthfb = fbmgr.get_byviewid(depth_viewid)
			return depthfb[#depthfb]
		end
		return {rbidx=create_depth_rb(fbsize.w, fbsize.h)}
	end
	return fbmgr.create({
		rbidx=fbmgr.create_rb(
		default_comp.render_buffer(
			fbsize.w, fbsize.h, "RGBA16F", sampler {
				RT= ENABLE_FXAA and "RT_ON" or "RT_MSAA4",
				MIN="LINEAR",
				MAG="LINEAR",
				U="CLAMP",
				V="CLAMP",
			})
	)}, get_depth_buffer())
end

function irender.create_main_queue(vr, camera_ref)
	local fbidx = create_main_fb(vr)
	ecs.create_entity {
		policy = {
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
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h, ratio=vr.ratio},
				fb_idx = fbidx,
			},
			primitive_filter = {
				filter_type = "main_view",
				table.unpack(LAYER_NAMES)
			},
			visible = true,
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
		--Force to enable HDR as RGBA16F
		local format<const> = "RGBA16F"
		local handle, width, height, pitch = irender.read_render_buffer_content(format, fbmgr.get(fbidx)[1].rbidx, force_read)
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
		flags = sampler {
			BLIT="BLIT_AS_DST|BLIT_READBACK_ON",
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

local fullquad_vbhandle = bgfx.create_vertex_buffer(bgfx.memory_buffer("b", {1, 1, 1}), declmgr.get "p10NIu".handle)
local fullquad<const> = {
	vb = {
		start = 0, num = 3,
		handle=fullquad_vbhandle,
	}
}
function irender.full_quad()
	return fullquad
end