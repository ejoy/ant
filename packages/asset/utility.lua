local lfs = require "filesystem.local"
local cr = import_package "ant.compile_resource"

local m = {}

function m.read_file(filename)
    local f = lfs.open(cr.compile(filename), "rb")
    local c = f:read "a"
    f:close()
    return c
end

return m
