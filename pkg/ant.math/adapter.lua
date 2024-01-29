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

    local mt = ozz.SkeletonMt().__index
    mt.joint = math3d_adapter.getter(mt.joint, "m", 3)
    mt = ozz.MatrixVectorMt().__index
    mt.joint = math3d_adapter.getter(mt.joint, "m", 3)

    ozz.LocalToModelJob = math3d_adapter.getter(ozz.LocalToModelJob, "m", 2)
    ozz.BuildSkinningMatrices = math3d_adapter.matrix(ozz.BuildSkinningMatrices, 5)
end

if not __ANT_RUNTIME__ then
    local ozzoffline = require "ozz.offline"
    if not ozzoffline.adapter then
        ozzoffline.adapter = true
        local mt = ozzoffline.RawAnimationMt().__index
        mt.push_prekey = math3d_adapter.format(mt.push_prekey, "vqv", 5)
    end
end
