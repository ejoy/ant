local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

local setting		= import_package "ant.settings".setting
local settingdata 	= setting:data()
local graphic_setting=settingdata.graphic


local default	= import_package "ant.general".default
local icamera	= ecs.import.interface "ant.camera|icamera"
local irender	= ecs.import.interface "ant.render|irender"

local fr_sys = ecs.system "forward_render_system"

function fr_sys:init()
	local vr = world.args.viewport
	local camera = icamera.create({
		name = "default_camera",
		frustum = default.frustum(vr.w/vr.h),
		exposure = {
			type 			= "manual",
			aperture 		= 16.0,
			shutter_speed 	= 0.008,
			ISO 			= 100,
		}
	})

	if not graphic_setting.disable_pre_z then
		irender.create_pre_depth_queue(vr, camera)
	end
	irender.create_main_queue(vr, camera)
end

local function update_pre_depth_queue()
	for de in w:select "pre_depth_queue render_target:in camera_ref:out" do
		for me in w:select "main_queue render_target:in camera_ref:in" do
			de.camera_ref = me.camera_ref
			local vr = me.render_target.view_rect
			local dvr = de.render_target.view_rect
			dvr.x, dvr.y, dvr.w, dvr.h = vr.x, vr.y, vr.w, vr.h
		end
	end
end

function fr_sys:data_changed()
	--TODO: need sub a event
	update_pre_depth_queue()
end