local ecs = ...
local w = ecs.world.w

local bgfx = require "bgfx"
local animodule = require "hierarchy".animation
local assetmgr 		= import_package "ant.asset"

local m = ecs.system "mesh_skinning"

local function set_skinning_transform(rc)
	local sm = rc.skinning_matrices
	bgfx.set_multi_transforms(sm:pointer(), sm:count())
end

local function build_transform(rc, skinning)
	rc.skinning_matrices = skinning.skinning_matrices
	rc.set_transform = set_skinning_transform
end

function m:entity_init()
	for e in w:select "INIT skinning:in render_object:in meshskin_result:in pose_result:in" do
		local skinning = e.skinning
		local skin = e.meshskin_result
		local count = skin.joint_remap and skin.joint_remap:count() or e.pose_result:count()
		skinning.skinning_matrices = animodule.new_bind_pose(count)
		skinning.skin = skin
		build_transform(e.render_object, skinning)
	end
end
