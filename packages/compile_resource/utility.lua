local lfs = require "filesystem.local"
local compile = require "compile"

local m = {}

function m.read_file(filename)
    local f = lfs.open(compile.compile(filename), "rb")
    local c = f:read "a"
    f:close()
    return c
end

return m
