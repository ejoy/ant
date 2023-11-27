local vfs = require "vfs"
local fastio = require "fastio"

local m = {}

function m.readall(path)
    local memory = vfs.read(path) or error(("`read `%s` failed."):format(path))
    return fastio.wrap(memory)
end

function m.readall_v(path)
    local memory = vfs.read(path) or error(("`read `%s` failed."):format(path))
    return memory
end

return m
