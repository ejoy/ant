local serialize = import_package "ant.serialize"
local lfs = require "filesystem.local"
local cr = import_package "ant.compile_resource"

local animodule = require "hierarchy.animation"

local function read_file(filename)
    local f = assert(lfs.open(filename, "rb"))
    local c = f:read "a"
    f:close()
    return c
end
return {
    loader = function (filename)
        local c = read_file(cr.compile(filename))
        local data = serialize.unpack(c)
        local ibm = data.inverse_bind_matrices
        return {
            inverse_bind_pose 	= animodule.new_bind_pose(ibm.num, ibm.value),
            joint_remap 		= animodule.new_joint_remap(data.joints)
        }
    end,
    unloader = function (res)
    end
}