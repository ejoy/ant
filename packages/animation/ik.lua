local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"

local assetpkg = import_package "ant.asset"
local asset = assetpkg.mgr

local ani_module = require "hierarchy.animation"

--there are 2 types in ik_data, which are 'two_bone'(IKTwoBoneJob) and 'aim'(IKAimJob).
ecs.component "ik_data"
	.type		"string"("aim")			-- can be 'two_bone'/'aim'
	.target 	"vector"{0, 0, 0, 1}	-- model space
	.pole_vector"vector"{0, 0, 0, 0}	-- model space
	.twist_angle"real" 	(0.0)
	.weight		"real"  (0.0)
	.joints		"string[]"{}			-- type == 'aim', #joints == 1, type == 'two_bone', #joints == 3, with start/mid/end
	["opt"].mid_axis"vector" {0, 0, 1, 0}
	["opt"].soften "real" 	(0.0)
	["opt"].up_axis"vector" {0, 1, 0, 0}
	["opt"].forward "vector"{0, 0, 1, 0}-- local space
	["opt"].offset "vector" {0, 0, 0, 0}-- local space

ecs.component "ik"
	.jobs 'ik_data{}'

local ik_p = ecs.policy "ik"
ik_p.require_component "skeleton"
ik_p.require_component "ik"
ik_p.require_component "pose_result"
ik_p.require_transform "build_pose_result"
ik_p.require_transform "build_ik"

ik_p.require_policy "pose_result"

local build_ik_tranform = ecs.transform "build_ik"
build_ik_tranform.input "skeleton"
build_ik_tranform.output "ik"

local function check_joints_in_hierarchy_chain(ske, joint_indices)
	for i=3, 2, -1 do
		local jidx = joint_indices[i]
		local pidx = ske:parent(jidx)

		local next_jidx = joint_indices[i-1]
		while pidx ~= next_jidx and pidx ~= 0 do
			pidx = ske:parent(pidx)
		end

		if pidx == 0 then
			error(string.format("ik joints can not use as foot ik, which joints must as parent clain:%d %d %d", joint_indices[1], joint_indices[2], joint_indices[3]))
		end
	end
end

function build_ik_tranform.process(e)
	local ske = asset.get_resource(e.skeleton.ref_path).handle
	local ik = e.ik

	for _, ikdata in pairs(ik.jobs) do
		local joint_indices = {}
		for _, jn in ipairs(ikdata.joints) do
			local jointidx = ske:joint_index(jn)
			if jointidx == nil then
				error(string.format("invalid joint name:%s", jn))
			end

			joint_indices[#joint_indices+1] = jointidx
		end

		if e.ik.type == "two_bone" then
			assert(#joint_indices == 3)

			check_joints_in_hierarchy_chain(joint_indices)
		end
		ikdata.joint_indices = joint_indices
	end
end

local ikdata_cache = {}
local function prepare_ikdata(ikdata)
	ikdata_cache.type		= ikdata.type
	ikdata_cache.target 	= ikdata.target.p
	ikdata_cache.pole_vector= ikdata.pole_vector.p
	ikdata_cache.weight		= ikdata.weight
	ikdata_cache.twist_angle= ikdata.twist_angle
	ikdata_cache.joint_indices= ikdata.joint_indices

	if ikdata.type == "aim" then
		ikdata_cache.forward	= ikdata.forward.p
		ikdata_cache.up_axis	= ikdata.up_axis.p
		ikdata_cache.offset		= ikdata.offset.p
	else
		assert(ikdata.type == "two_bone")
		ikdata_cache.soften		= ikdata.soften
		ikdata_cache.mid_axis	= ikdata.mid_axis.p
	end
	return ikdata_cache
end

local fix_root <const> = true

local ik_i = ecs.interface "ik"
function ik_i.setup(e)
	local skehandle = asset.get_resource(e.skeleton.ref_path).handle
	ani_module.setup(e.pose_result.result, skehandle, fix_root)
end

function ik_i.do_ik(ikdata)
	ani_module.do_ik(prepare_ikdata(ikdata))
end