local fs = require "filesystem"
local lfs = require "filesystem.local"
local datalist  = require "datalist"
local animodule = require "hierarchy".animation
local assetmgr 	= import_package "ant.asset"

local function read_file(filename)
    local f = assert(lfs.open(filename:localpath(), "rb"))
    local c = f:read "a"
    f:close()
    return c
end
return {
    loader = function (filename, world)
        local iani = world._ecs["ant.animation"].import.interface "ant.animation|ianimation"
        local path = fs.path(filename)
        local data = datalist.parse(read_file(path))
        local ske = assetmgr.resource(data.skeleton)
        local raw_animation = animodule.new_raw_animation()
        raw_animation:setup(ske._handle, data.duration)
        return {
            _duration = data.duration,
            _sampling_context = animodule.new_sampling_context(1),
            _handle = iani.build_animation(ske._handle, raw_animation, data.joint_anims, data.sample_ratio),
        }
    end,
    unloader = function (res)
    end
}