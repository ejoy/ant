local ecs = ...
local world = ecs.world
local w = world.w

local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant
local irender	= ecs.import.interface "ant.render|irender"
local default	= import_package "ant.general".default
local icamera	= ecs.import.interface "ant.camera|camera"

local fr_sys = ecs.system "forward_render_system"

function fr_sys:init()
	local vr = {x=0, y=0, w=world.args.width,h=world.args.height}
	local camera = icamera.create({
		eyepos  = mc.ZERO_PT,
		viewdir = mc.ZAXIS,
		updir	= mc.YAXIS,
		frustum = default.frustum(vr.w/vr.h),
        name = "default_camera",
	})
	irender.create_main_queue(vr, camera)
	--irender.create_pre_depth_queue(vr, camera)
end

local function update_pre_depth_queue()
	for de in w:select "pre_depth_queue render_target:out camera_eid:out" do
		for me in w:select "main_queue render_target:in camera_eid:in" do
			de.camera_eid = me.camera_eid
			local vr = me.render_target.view_rect
			de.render_target.view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h}
		end
	end
end

function fr_sys:data_changed()
	--update_pre_depth_queue()
end