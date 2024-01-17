local serialize = import_package "ant.serialize"
local aio       = import_package "ant.io"
local ozz       = require "ozz"

local function loader(filename)
    local data = serialize.parse(filename, aio.readall(filename))
    data.skeleton = ozz.load(aio.readall(data.skeleton))
    for k, v in pairs(data.animations) do
        data.animations[k] = ozz.load(aio.readall(v))
    end
    return data
end

local function unloader()
end

return {
    loader = loader,
    unloader = unloader,
}
