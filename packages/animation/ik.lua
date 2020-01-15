local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

local ik_module = require "hierarchy.ik"

--there are 2 types in ik_data, which are 'two_bone'(IKTwoBoneJob) and 'aim'(IKAimJob).
ecs.component "ik_data"
	.type		"string"("aim")			-- can be 'two_bone'/'aim'
	.target 	"vector"{0, 0, 0, 1}	-- model space
	.pole_vector"vector"{0, 0, 0, 0}	-- model space
	.upaxis		"vector"{0, 1, 0, 0}	-- local space, same as IKTwoBoneJob's mid_axis
	.twist_angle"real" 	(0.0)
	.joints		"string[]"("")			-- type == 'aim', #joints == 1, type == 'two_bone', #joints == 3, with start/mid/end
	["opt"].soften "real" (0.0)
	["opt"].forward "vector"{0, 0, 1, 0}-- local space
	["opt"].offset "vector" {0, 0, 0, 0}-- local space

ecs.component "ik"
	.jobs 'ik_data[]'

local p = ecs.policy 'ik'
	p.require_component 'ik'
	p.require_component 'skeleton'
	p.require_component 'transform'

	p.require_system 'ik_system'


local ik_sys = ecs.system "ik_system"

local ikcomp_cache = {}
local function prepare_ik_data(transform, ikcomp)
	ikcomp_cache.type = ikcomp.type

	local invmat = ms:inverse(ms:srtmat(transform), "P")

	-- ik need all data work in model space
	ikcomp_cache.target 	= ms(invmat, ikcomp.target, "*m")
	ikcomp_cache.pole_vector= ms(invmat, ikcomp.pole_vector, "*m")

	ikcomp_cache.upaxis 	= ms(ikcomp.upaxis, "m")

	if ikcomp.forward then
		ikcomp_cache.forward = ms(ikcomp.forward, "m")
	end

	if ikcomp.offset then
		ikcomp_cache.offset	= ms(ikcomp.offset, "m")
	end

	ikcomp_cache.weight 	= ikcomp.weight
	ikcomp_cache.twist_angle= ikcomp.twist_angle

	ikcomp_cache.soften 	= ikcomp.soften
	ikcomp_cache.joints 	= ikcomp.joints

	return ikcomp_cache
end

local fixroot <const> = true

function ik_sys:do_ik()
	for _, eid in world:each "ik" do
		local e = world[eid]

		for _, ikdata in ipairs(e.ik.jobs) do
			ik_module.do_ik(e.skeleton.handle, e.pose_result.result, fixroot, prepare_ik_data(e.transform, ikdata))
		end
	end
end

-- local mathadapter_util = import_package "ant.math.adapter"
-- local math3d_adapter = require "math3d.adapter"
-- mathadapter_util.bind("animation", function ()
-- 	ik_module.do_ik = math3d_adapter.matrix(ms, ik_module.do_ik, 1)
-- end)