local thread = require "thread"
local fs = require "filesystem"
local cr = import_package "ant.compile_resource"

local animodule = require "hierarchy.animation"

local function read_file(filename)
    local f = assert(fs.open(filename, "rb"))
    local c = f:read "a"
    f:close()
    return c
end
return {
    loader = function (filename)
        local c = read_file(cr.compile(filename))
        local data = thread.unpack(c)
        local ibm = data.inverse_bind_matrices
        return {
            inverse_bind_pose 	= animodule.new_bind_pose(ibm.num, ibm.value),
            joint_remap 		= animodule.new_joint_remap(data.joints)
        }
    end,
    unloader = function (res)
    end
}