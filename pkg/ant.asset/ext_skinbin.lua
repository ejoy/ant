local serialization = require "bee.serialization"
local aio = import_package "ant.io"
local ozz = require "ozz"

return {
    loader = function (filename)
        local c = aio.readall(filename)
        local data = serialization.unpack(c)
        return {
            inverse_bind_pose = ozz.MatrixVector(data.inverse_bind_matrices),
            joint_remap = ozz.Uint16Verctor(data.joints)
        }
    end,
    unloader = function (res)
    end
}
