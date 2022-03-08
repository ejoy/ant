local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local icamera = ecs.import.interface "ant.camera|icamera"

local setting = import_package "ant.settings".setting
local curveworld = setting:data().graphic.curve_world

local icp = ecs.interface "icull_primitive"

local function cull(cull_tags, vp_mat)
	local frustum_planes = math3d.frustum_planes(vp_mat)

	for _, culltag in ipairs(cull_tags) do
		w:clear(culltag)
		for vv in w:select(("render_object:in name?in %s?out"):format(culltag)) do
			local aabb = vv.render_object.aabb
			if aabb and math3d.frustum_intersect_aabb(frustum_planes, aabb) < 0 then
				vv[culltag] = true
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
	if curveworld.enable then
		return 
	end
	for v in w:select "visible camera_ref:in render_target:in cull_tag:in" do
		local camera = world:entity(v.camera_ref).camera
		cull(v.cull_tag, camera.viewprojmat)
	end
end
