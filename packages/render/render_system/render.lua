local ecs = ...
local world = ecs.world
local mc = import_package "ant.math".constant

local default_comp 	= import_package "ant.general".default
local setting		= import_package "ant.settings".setting

local bgfx 			= require "bgfx"
local viewidmgr 	= require "viewid_mgr"
local fbmgr			= require "framebuffer_mgr"
local samplerutil	= require "sampler"

local imaterial		= world:interface "ant.asset|imaterial"
local ipf			= world:interface "ant.scene|iprimitive_filter"

local vpt = ecs.transform "visible_primitive_transform"
local function parse_rc(rc)
	local pdq = world:singleton_entity "pre_depth_queue"
	if pdq then
		local state = bgfx.parse_state(rc.state)
		state.WRITE_MASK = state.WRITE_MASK:gsub("Z", "")
		return setmetatable({
			state = bgfx.make_state(state)
		}, {__index=rc})
	end
	return rc
end
function vpt.process_entity(e)
	local f = e.primitive_filter
	f.insert_item = function (filter, fxtype, eid, rc)
		local items = filter.result[fxtype].items
		if rc then
			rc.eid = eid
			ipf.add_item(items, eid, parse_rc(rc))
		else
			ipf.remove_item(items, eid)
		end
	end
end

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

local pre_depth_material_file<const> 	= "/pkg/ant.resources/materials/depth.material"
local pre_depth_material, pre_depth_skinning_material

local function can_write_depth(state)
	local s = bgfx.parse_state(state)
	local wm = s.WRITE_MASK
	return wm == nil or wm:match "Z"
end

local pd_pt = ecs.transform "pre_depth_primitive_transform"
function pd_pt.process_entity(e)
	if pre_depth_material == nil then
		pre_depth_material 			= imaterial.load(pre_depth_material_file, {depth_type="linear"})
		pre_depth_skinning_material = imaterial.load(pre_depth_material_file, {depth_type="linear", skinning="GPU"})
	end

	e.primitive_filter.insert_item = function (filter, fxtype, eid, rc)
		if fxtype == "opaticy" then
			local items = filter.result[fxtype].items
			local material = world[eid].skinning_type == "GPU" and pre_depth_skinning_material or pre_depth_material
			if rc then
				if can_write_depth(rc.state) then
					ipf.add_item(items, eid, setmetatable({
						eid			= eid,
						properties	= material.properties,
						fx			= material.fx,
						state		= irender.check_primitive_mode_state(rc.state, material.state),
					}, {__index=rc}))
				end
			else
				ipf.remove_item(items, eid)
			end
		end
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
			view_queue = true
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
		if pd then
			local pd_fb = fbmgr.get(pd.render_target.fb_idx)
			return pd_fb[#pd_fb], true
		end

		return fbmgr.create_rb{
			format = "D24S8",
			w = view_rect.w, h=view_rect.h,
			layers = 1,
			flags = rb_flag,
		}
	end

	local function get_clear_state()
		local pd = world:singleton_entity "pre_depth_queue"
		local cs = {
			color = rs.clear_color or 0x000000ff,
			color1 = 0,
			clear = "C",
		}
		if pd == nil then
			cs.depth = 1
			cs.stencil = 0
			cs.clear = "CDS"
		end
		return cs
	end

	local cs = get_clear_state()

	local db, ownership = get_depth_buffer()
	render_buffers[#render_buffers+1] = db
	if ownership then
		local os = {}; os[db] = "pre_depth_queue"
		render_buffers.ownerships = os
	end

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
				clear_state = cs,
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

local clear_colornames<const> = {
	"color1", "color2","color3","color4","color5","color6", "color7"
}

local function set_view_clear(viewid, cs)
	-- if cs.color1 then
	-- 	bgfx.set_view_clear_mrt(viewid, cs.clear, cs.depth, cs.stencil,
	-- 		cs.color, cs.color1, cs.color2, cs.color3,
	-- 		cs.color4, cs.color5, cs.color6, cs.color7)
	-- else
		bgfx.set_view_clear(viewid, cs.clear, cs.color, cs.depth, cs.stencil)
	-- end
end

function irq.set_view_clear(eid, what, color, depth, stencil)
	local rt = world[eid].render_target
	local cs = rt.clear_state
	cs.color = color
	cs.depth = depth
	cs.stencil = stencil

	cs.clear = what
	set_view_clear(rt.viewid, cs)
	world:pub{"component_changed", "clear_state", eid}
end

function irq.set_view_rect(eid, rect)
	local qe = world[eid]
	local rt = qe.render_target
	local vr = rt.view_rect
	vr.x, vr.y = rect.x, rect.y
	vr.w, vr.h = rect.w, rect.h
	icamera.set_frustum_aspect(qe.camera_eid, vr.w/vr.h)
	bgfx.set_view_rect(rt.viewid, vr.x, vr.y, vr.w, vr.h)
	world:pub{"component_changed", "view_rect", eid}
end

function irq.set_frame_buffer(eid, fbidx)
	local rt = world[eid].render_target
	rt.fb_idx = fbidx
	world:pub{"component_changed", "framebuffer", eid}
end

function irq.set_camera(eid, cameraeid)
	world[eid].camera_eid = cameraeid
	world:pub{"component_changed", "camera_eid", eid}
end

function irq.set_visible(eid, b)
	local q = world[eid]
	q.visible = b

	world:pub{"component_changed", "visible", eid}
end

function irq.update_rendertarget(rt)
	local viewid = rt.viewid
	local vm = rt.view_mode or ""
	bgfx.set_view_mode(viewid, vm)
	local vr = rt.view_rect
	bgfx.set_view_rect(viewid, vr.x, vr.y, vr.w, vr.h)
	local cs = rt.clear_state
	set_view_clear(viewid, cs)
	
	local fb_idx = rt.fb_idx
	if fb_idx then
		fbmgr.bind(viewid, fb_idx)
	else
		rt.fb_idx = fbmgr.get_fb_idx(viewid)
	end
end

local rt = ecs.component "render_target"
function rt:init()
	irq.update_rendertarget(self)
	return self
end

function rt:delete()
	fbmgr.unbind(self.viewid)
end
