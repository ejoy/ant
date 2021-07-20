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
		local vp_mat = world[rq.camera_eid]._rendercache.viewprojmat
		local frustum_planes = math3d.frustum_planes(vp_mat)
		local CullTag = rq.tag.."_cull"
		w:clear(CullTag)
		for i = 1, #rq.layer do
			if NeedCull[rq.layer[i]] then
				for u in w:select(rq.tag .. "_" .. rq.layer[i] .. " render_object:in " .. CullTag .. ":temp") do
					local aabb = u.render_object.aabb
					if not aabb or math3d.frustum_intersect_aabb(frustum_planes, aabb) >= 0 then
						u[CullTag] = true
					end
				end
			else
				for u in w:select(rq.tag .. "_" .. rq.layer[i] .. " " .. CullTag .. ":temp") do
					u[CullTag] = true
				end
			end
		end
	end
end
