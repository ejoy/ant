local ecs = ...
local world = ecs.world
local w = world.w

local animodule = require "hierarchy".animation
local math3d 	= require "math3d"

local assetmgr 	= import_package "ant.asset"

local sm = ecs.transform "skinning_material"

function sm.process_prefab(e)
	if e.animation and e.skeleton then
		e._cache_prefab.material_setting.skinning = "GPU"
	end
end

-- skinning system
local skinning_sys = ecs.system "skinning_system"

local iom = world:interface "ant.objcontroller|obj_motion"
local r2l_mat<const> = math3d.ref(math3d.matrix{s={1.0, 1.0, -1.0}})
function skinning_sys:skin_mesh()
	for e in w:select "pose_result:in skinning:in" do
		local skinning = e.skinning
		local skin = skinning.skin
		local skinning_matrices = skinning.skinning_matrices
		local pr = e.pose_result

		local m = math3d.mul(iom.worldmat(e), r2l_mat)
		animodule.build_skinning_matrices(skinning_matrices, pr, skin.inverse_bind_pose, skin.joint_remap, m)
	end
end
