local ecs = ...
local world = ecs.world

local mathpkg = import_package "ant.math"

local assetpkg = import_package "ant.asset"
local asset = assetpkg.mgr

local ani_module = require "hierarchy.animation"

local ikdata_cache = {}
local function prepare_ikdata(ikdata)
	ikdata_cache.type		= ikdata.type
	ikdata_cache.target 	= ~ikdata.target
	ikdata_cache.pole_vector= ~ikdata.pole_vector
	ikdata_cache.weight		= ikdata.weight
	ikdata_cache.twist_angle= ikdata.twist_angle
	ikdata_cache.joint_indices= ikdata.joint_indices

	if ikdata.type == "aim" then
		ikdata_cache.forward	= ~ikdata.forward
		ikdata_cache.up_axis	= ~ikdata.up_axis
		ikdata_cache.offset		= ~ikdata.offset
	else
		assert(ikdata.type == "two_bone")
		ikdata_cache.soften		= ikdata.soften
		ikdata_cache.mid_axis	= ~ikdata.mid_axis
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