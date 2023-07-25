local math3d    = require "math3d"
local async     = require "async"
local mathpkg   = import_package "ant.math"
local serialization = require "bee.serialization"
local mc        = mathpkg.constant

local animodule = require "hierarchy".animation

local function read_file(filename)
    local f = assert(io.open(filename, "rb"))
    local c = f:read "a"
    f:close()
    return c
end

local r2l_mat<const> = mc.R2L_MAT

return {
    loader = function (filename)
        local c = read_file(async.compile(filename))
        local data = serialization.unpack(c)
        local ibm = data.inverse_bind_matrices

        local ibp = animodule.new_bind_pose(ibm.num, ibm.value)
        ibp:transform(math3d.value_ptr(r2l_mat))
        return {
            inverse_bind_pose 	= ibp,
            joint_remap 		= animodule.new_joint_remap(data.joints)
        }
    end,
    unloader = function (res)
    end
}