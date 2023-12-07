local math3d = require "math3d"
local math3d_adapter = require "math3d.adapter" (math3d._COBJECT)

local bgfx = require "bgfx"
if not bgfx.adapter then
    bgfx.adapter = true
    bgfx.set_transform = math3d_adapter.matrix(bgfx.set_transform, 1, 1)
    bgfx.set_view_transform = math3d_adapter.matrix(bgfx.set_view_transform, 2, 2)
    bgfx.set_uniform = math3d_adapter.variant(bgfx.set_uniform_matrix, bgfx.set_uniform_vector, 2)
    bgfx.set_uniform_command = math3d_adapter.variant(bgfx.set_uniform_matrix_command, bgfx.set_uniform_vector_command, 2)
    local idb = bgfx.instance_buffer_metatable()
    idb.pack = math3d_adapter.format(idb.pack, idb.format, 3)
    idb.__call = idb.pack
end

local ozz = require "ozz"
if not ozz.adapter then
    ozz.adapter = true

    --local bd_mt = ozz.skeleton.builddata_metatable()
    --bd_mt.joint = math3d_adapter.getter(bd_mt.joint, "m", 3)

    local mt = ozz.bind_pose_mt()
    mt.joint = math3d_adapter.getter(mt.joint, "m", 3)
    mt = ozz.pose_result_mt()
    mt.joint = math3d_adapter.getter(mt.joint, "m", 3)
    mt.joint_local_srt = math3d_adapter.format(mt.joint_local_srt, "vqv", 3)
    mt.fetch_result = math3d_adapter.getter(mt.fetch_result, "m", 2)
    mt = ozz.raw_animation_mt()
    mt.push_prekey = math3d_adapter.format(mt.push_prekey, "vqv", 4)
    ozz.build_skinning_matrices = math3d_adapter.matrix(ozz.build_skinning_matrices, 5)
end
