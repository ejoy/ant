local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local setting = import_package "ant.settings".setting
local disable_cull = setting:data().graphic.disable_cull

local icp = ecs.interface "icull_primitive"

local function cull(cull_tags, vp_mat)
	local frustum_planes = math3d.frustum_planes(vp_mat)
	for vv in w:select "scene_changed view_visible scene:in" do
		local aabb = vv.scene.scene_aabb
		if aabb and math3d.frustum_intersect_aabb(frustum_planes, aabb) < 0 then
			for i=1, #cull_tags do
				vv[cull_tags[i]] = true
			end
		end
	end
end

icp.cull = cull

local cull_sys = ecs.system "cull_system"

function cull_sys:entity_ready()
	for qe in w:select "filter_created primitive_filter:in cull_tag:in" do
		local culltag = qe.cull_tag
		for idx, fn in ipairs(qe.primitive_filter) do
			local cn = fn .. "_cull"
			w:register {name = cn}
			culltag[idx] = cn
		end
	end
end

function cull_sys:cull()
	if disable_cull then 
		return
	end

	for v in w:select "visible camera_ref:in render_target:in cull_tag:in" do
		local camera = world:entity(v.camera_ref).camera
		cull(v.cull_tag, camera.viewprojmat)
	end
end
