local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local icamera = world:interface "ant.camera|camera"

local icp = ecs.interface "icull_primitive"

function icp.cull(filter, vp_mat)
end

local cull_sys = ecs.system "cull_system"

function cull_sys:entity_init()
	for qe in w:select "INIT filter_names:in cull_tag:in" do
		local culltag = qe.cull_tag
		for idx, fn in ipairs(qe.filter_names) do
			culltag[idx] = fn .. "_cull"
		end
	end
end

function cull_sys:cull()
	for v in w:select "visible camera_eid:in render_target:in cull_tag:in" do
		local camera = icamera.find_camera(v.camera_eid)
		if camera then
			local vp_mat = camera.viewprojmat
			if vp_mat then
				local frustum_planes = math3d.frustum_planes(vp_mat)

				for _, culltag in ipairs(v.cull_tag) do
					w:clear(culltag)
					for vv in w:select(("render_object:in %s?out"):format(culltag)) do
						local aabb = vv.render_object.aabb
						if aabb and math3d.frustum_intersect_aabb(frustum_planes, aabb) < 0 then
							vv[culltag] = true
						end
					end
				end
			end
		end
	end
end
