local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"

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
	for v in w:select "visible render_queue:in" do
		local rq = v.render_queue
		local camera = w:object("camera_node", rq.camera_id)
		local vp_mat = camera.viewprojmat
		local frustum_planes = math3d.frustum_planes(vp_mat)
		local cull_tag = rq.cull_tag
		for i = 1, #rq.layer_tag do
			if NeedCull[rq.layer[i]] then
				for u in w:select(rq.layer_tag[i] .. " render_object:in " .. cull_tag .. ":temp") do
					local aabb = u.render_object.aabb
					if aabb and math3d.frustum_intersect_aabb(frustum_planes, aabb) < 0 then
						u[cull_tag] = true
					end
				end
			end
		end
	end
end
