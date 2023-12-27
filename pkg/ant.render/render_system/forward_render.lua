local ecs = ...
local world = ecs.world
local w = world.w

local default	= import_package "ant.general".default
local icamera	= ecs.require "ant.camera|camera"
local irender	= ecs.require "ant.render|render_system.render"
local iviewport = ecs.require "ant.render|viewport.state"

local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util

local fr_sys = ecs.system "forward_render_system"

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

	if irender.use_pre_depth() then
		irender.create_pre_depth_queue(vr, camera)
	end
	irender.create_main_queue(vr, camera)
end

local mq_vr_changed = world:sub{"view_rect_changed", "main_queue"}

function fr_sys:data_changed()
	if irender.use_pre_depth() then
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