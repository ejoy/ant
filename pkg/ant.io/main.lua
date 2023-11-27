local vfs = require "vfs"
local fastio = require "fastio"

local m = {}

local function readall(path)
    local memory = vfs.read(path) or error(("`read `%s` failed."):format(path))
    return memory
end

function m.readall(path)
    return fastio.wrap(readall(path))
end

function m.readall_s(path)
    return fastio.tostring(readall(path))
end

function m.readall_v(path)
    return readall(path)
end

return m
