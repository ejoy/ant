local ecs = ...
local world = ecs.world

local bgfx = require "bgfx"
local irq = world:interface "ant.render|irenderqueue"
local irender = world:interface "ant.render|irender"
local default_comp 	= import_package "ant.general".default
local icamera	= world:interface "ant.camera|camera"

local fr_sys = ecs.system "forward_render_system"
local pd_mbs = {}

function fr_sys:init()
	local vr = {w=world.args.width,h=world.args.height}
	local camera_ref = icamera.create({
		eyepos  = {0, 0, 0, 1},
		viewdir = {0, 0, 1, 0},
		frustum = default_comp.frustum(vr.w/vr.h),
        name = "default_camera",
	})

	irender.create_blit_queue(vr)
	irender.create_main_queue(vr, camera_ref)
end

function fr_sys:data_changed()
	for _, d in pairs(pd_mbs) do
		local cb = d.cb
		for msg in d.mb:each() do
			cb(msg)
		end
	end
end