local serialize = import_package "ant.serialize"
local aio       = import_package "ant.io"
local assetmgr  = import_package "ant.asset"
local ozz       = require "ozz"
local fs        = require "filesystem"

local function loader(filename)
    local data = serialize.parse(filename, aio.readall(filename))
    data.skeleton = ozz.load(aio.readall(data.skeleton))
    for k, v in pairs(data.animations) do
        if fs.path(v):equal_extension ".anim" then
            --TODO: remove it
            data.animations[k] = assetmgr.resource(v)
        else
            data.animations[k] = ozz.load(aio.readall(v))
        end
    end
    return data
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
