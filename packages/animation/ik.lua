local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

local ik_module = require "hierarchy.ik"

ecs.component "ik"
	.target "vector"
	.pole_vector "vector"
	.mid_axis "vector"
	.weight "real" (0.0)
	.soften "real" (0.0)
	.twist_angle "real" (0.0)
	.start_joint "int" (-1)
	.mid_joint "int" (-1)
	.end_joint "int" (-1)

local p = ecs.policy "ik"
p.require_component "ik"
p.require_component "skeleton"
p.require_component "transform"
p.require_component "pose_result"

p.require_transform "pose_result"

p.require_system "ik_system"

local ik_system = ecs.system "ik_system"

local ikcomp_cache = {}
local function prepare_ik(transform, ikcomp)
	local invmat = ms:inverse(ms:srtmat(transform), "P")

	-- ik need all data work in model space
	ikcomp_cache.target 		= ms(invmat, ikcomp.target, "*m")
	ikcomp_cache.pole_vector 	= ms(invmat, ikcomp.pole_vector, "*m")

	ikcomp_cache.mid_axis 		= ms(ikcomp.mid_axis, "m")

	ikcomp_cache.weight 		= ikcomp.weight
	ikcomp_cache.soften 		= ikcomp.soften
	ikcomp_cache.twist_angle 	= ikcomp.twist_angle

	ikcomp_cache.start_joint 	= ikcomp.start_joint
	ikcomp_cache.mid_joint 		= ikcomp.mid_joint
	ikcomp_cache.end_joint 		= ikcomp.end_joint
	return ikcomp_cache
end

function ik_system:ik()
	for _, eid in world:each "ik" do
		local e = world[eid]
		local fixroot <const> = true
		ik_module.do_ik(e.skeleton.handle, e.pose_result.result, fixroot, prepare_ik(e.transform, e.ik))
	end
end

-- local mathadapter_util = import_package "ant.math.adapter"
-- local math3d_adapter = require "math3d.adapter"
-- mathadapter_util.bind("animation", function ()
-- 	ik_module.do_ik = math3d_adapter.matrix(ms, ik_module.do_ik, 1)
-- end)