if import_package then
    return import_package "ant.json"
end
require "runtime.vfs"
local vfs = require "vfs"
local path = vfs.realpath "/pkg/ant.json/json.lua"
local f = assert(io.open(path))
local data = f:read "a"
f:close()
return assert(load(data, "/pkg/ant.json/json.lua"))()
