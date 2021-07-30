local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local icamera = world:interface "ant.camera|camera"

local icp = ecs.interface "icull_primitive"

function icp.cull(filter, vp_mat)
end

local cull_sys = ecs.system "cull_system"

local NeedCull <const> = {
	translucent	= true,
	opaticy		= true,
	decal		= true,
}

function cull_sys:cull()
	for v in w:select "visible camera_eid:in render_target:in queue_name:in" do
		local camera = icamera.find_camera(v.camera_eid)
		local vp_mat = camera.viewprojmat
		local frustum_planes = math3d.frustum_planes(vp_mat)
		local culltag = v.queue_name .. "_cull?out"
		for vv in w:select("render_object:in " .. culltag) do
			local aabb = vv.render_object.aabb
			if aabb and math3d.frustum_intersect_aabb(frustum_planes, aabb) < 0 then
 				vv[culltag] = true
 			end
		end
	end
end
