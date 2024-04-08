local ecs = ...
local world = ecs.world
local w = world.w

local icamera	= ecs.require "ant.camera|camera"
local iviewport = ecs.require "ant.render|viewport.state"
local fbmgr		= require "framebuffer_mgr"
local fg		= ecs.require "ant.render|framegraph"

local default	= import_package "ant.general".default
local hwi		= import_package "ant.hwi"

local sampler	= import_package "ant.render.core".sampler

local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util

local default_comp 	= import_package "ant.general".default
local setting		= import_package "ant.settings"

local ENABLE_PRE_DEPTH<const>	= not setting:get "graphic/disable_pre_z"
local ENABLE_FXAA<const> 		= setting:get "graphic/postprocess/fxaa/enable"
local ENABLE_TAA<const>			= setting:get "graphic/postprocess/taa/enable"

local INV_Z<const> = setting:get "graphic/inv_z"
local CLEAR_DEPTH_VALUE<const>  = INV_Z and 0 or 1

local fr_sys = ecs.system "forward_render_system"

local function get_clear_state()
	local clearcolor = setting:get "graphic/render/clear_color" or 0x000000ff
	return ENABLE_PRE_DEPTH and	{
			clear 	= "C",
			color 	= clearcolor,
		} or  {
			clear 	= "CDS",
			color 	= clearcolor,
			depth 	= 0.0,
			stencil = 0.0
	}
end

local function create_depth_rb(ww, hh)
	return fbmgr.create_rb{
		format = "D24S8",
		w = ww, h = hh,
		layers = 1,
		flags = sampler {
			RT = (ENABLE_FXAA or ENABLE_TAA) and "RT_ON" or "RT_MSAA4|RT_WRITE",
			MIN="LINEAR",
			MAG="LINEAR",
			U="CLAMP",
			V="CLAMP",
		},
	}
end

local function create_predepth_queue(vr, cameraref)
	local fbidx = fbmgr.create{rbidx = create_depth_rb(vr.w, vr.h)}
	local predepth_viewid<const> = hwi.viewid_get "pre_depth"
	fbmgr.bind(predepth_viewid, fbidx)

	world:create_entity {
		policy = {
			"ant.render|pre_depth_queue",
			"ant.render|watch_screen_buffer",
		},
		data = {
			camera_ref = cameraref,
			render_target = {
				viewid = predepth_viewid,
				clear_state = {
					clear = "SD",
					depth = CLEAR_DEPTH_VALUE,
					stencil = 0
				},
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h, ratio=vr.ratio},
				fb_idx = fbidx,
			},
			queue_name 		= "pre_depth_queue",
			visible 		= true,
			pre_depth_queue = true,
			submit_queue	= true,
			watch_screen_buffer = true,
		}
	}
end

local function create_main_fb(fbsize)
	local function get_depth_buffer()
		if ENABLE_PRE_DEPTH then
			local depth_viewid = hwi.viewid_get "pre_depth"
			local depthfb = fbmgr.get_byviewid(depth_viewid)
			return depthfb[#depthfb]
		end
		return {rbidx=create_depth_rb(fbsize.w, fbsize.h)}
	end
	return fbmgr.create({
		rbidx=fbmgr.create_rb(
		default_comp.render_buffer(
			fbsize.w, fbsize.h, "RGBA16F", sampler {
				RT= (ENABLE_FXAA or ENABLE_TAA) and "RT_ON" or "RT_MSAA4",
				MIN="LINEAR",
				MAG="LINEAR",
				U="CLAMP",
				V="CLAMP",
			})
	)}, get_depth_buffer())
end

local function create_main_queue(vr, cameraref)
	local fbidx = create_main_fb(vr)
	world:create_entity {
		policy = {
			"ant.render|watch_screen_buffer",
			"ant.render|main_queue",
		},
		data = {
			camera_ref = cameraref,
			render_target = {
				viewid		= hwi.viewid_get "main_view",
				view_mode 	= "d",
				clear_state	= get_clear_state(),
				view_rect 	= {x=vr.x, y=vr.y, w=vr.w, h=vr.h, ratio=vr.ratio},
				fb_idx 		= fbidx,
			},
			visible = true,
			main_queue = true,
			submit_queue = true,
			watch_screen_buffer = true,
			queue_name = "main_queue",
		}
	}
end

function fr_sys:init()
	local vr = iviewport.viewrect
	local camera = icamera.create{
		name = "default_camera",
		frustum = default.frustum(vr.w/vr.h),
		exposure = {
			type 			= "manual",
			aperture 		= 16.0,
			shutter_speed 	= 0.008,
			ISO 			= 100,
		}
	}

	if ENABLE_PRE_DEPTH then
		create_predepth_queue(vr, camera)
	end
	create_main_queue(vr, camera)
end

local mq_vr_changed = world:sub{"view_rect_changed", "main_queue"}

if ENABLE_PRE_DEPTH then
	function fr_sys:data_changed()
		local mq = w:first "main_queue camera_ref:in"
		local ce = world:entity(mq.camera_ref, "camera_changed?in")
		if ce.camera_changed then
			local pdq = w:first "pre_depth_queue camera_ref:out"
			pdq.camera_ref = mq.camera_ref
			w:submit(pdq)
		end

		for _, _, vr in mq_vr_changed:unpack() do
			local pdq = w:first "pre_depth_queue render_target:in"
			mu.copy2viewrect(vr, pdq.render_target.view_rect)
		end
	end
end