local math3d    = require "math3d"
local lfs       = require "filesystem.local"

local cr        = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local animodule = require "hierarchy".animation

local function read_file(filename)
    local f = assert(lfs.open(filename, "rb"))
    local c = f:read "a"
    f:close()
    return c
end

local r2l_mat<const> = math3d.ref(math3d.matrix{s={1.0, 1.0, -1.0}})

return {
    loader = function (filename)
        local c = read_file(cr.compile(filename))
        local data = serialize.unpack(c)
        local ibm = data.inverse_bind_matrices

        local ibp = animodule.new_bind_pose(ibm.num, ibm.value)
        ibp:transform(r2l_mat.p)
        return {
            inverse_bind_pose 	= ibp,
            joint_remap 		= animodule.new_joint_remap(data.joints)
        }
    end,
    unloader = function (res)
    end
}