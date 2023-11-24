local vfs = require "vfs"
local fastio = require "fastio"

local m = {}

function m.readall(path)
    local memory = vfs.read(path) or error(("`read `%s` failed."):format(path))
    return fastio.wrap(memory)
end

return m
