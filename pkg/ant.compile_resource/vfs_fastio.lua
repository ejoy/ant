local fastio = require "fastio"

local m = {}

function m.readall_f(vfs, path)
    local realpath = assert(vfs.realpath(path), path)
    return fastio.readall_f(realpath, path)
end

return m
