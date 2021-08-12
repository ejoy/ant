local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"
local irq = world:interface "ant.render|irenderqueue"
local irender = world:interface "ant.render|irender"
local default_comp 	= import_package "ant.general".default
local icamera	= world:interface "ant.camera|camera"

local fr_sys = ecs.system "forward_render_system"
local pd_mbs = {}

function fr_sys:init()
	local vr = {x=0, y=0, w=world.args.width,h=world.args.height}
	local camera_eid = icamera.create({
		eyepos  = {0, 0, 0, 1},
		viewdir = {0, 0, 1, 0},
		frustum = default_comp.frustum(vr.w/vr.h),
        name = "default_camera",
	})

	irender.create_blit_queue(vr)
	irender.create_main_queue(vr, camera_eid)
	--irender.create_pre_depth_queue(vr, camera_eid)
end

local function update_pre_depth_queue()
	for de in w:select "pre_depth_queue render_target:out camera_eid:out" do
		for me in w:select "main_queue render_target:in camera_eid:in" do
			de.camera_eid = me.camera_eid
			de.render_target.view_rect = me.render_target.view_rect
		end
	end
end

function fr_sys:data_changed()
	--update_pre_depth_queue()
end