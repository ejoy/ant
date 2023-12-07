local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local serialization = require "bee.serialization"
local aio = import_package "ant.io"
local mc = mathpkg.constant

local ozz = require "ozz"

local r2l_mat<const> = mc.R2L_MAT

return {
    loader = function (filename)
        local c = aio.readall(filename)
        local data = serialization.unpack(c)
        local ibm = data.inverse_bind_matrices

        local ibp = ozz.new_bind_pose(ibm.num, ibm.value)
        ibp:transform(math3d.value_ptr(r2l_mat))
        return {
            inverse_bind_pose 	= ibp,
            joint_remap 		= ozz.new_joint_remap(data.joints)
        }
    end,
    unloader = function (res)
    end
}