function package.readfile(filename)
    local vfs = require 'vfs'
    local vpath = assert(package.searchpath(filename, package.path))
    local lpath = assert(vfs.realpath(vpath))
    local f = assert(io.open(lpath))
    local str = f:read 'a'
    f:close()
    return str
end
require 'runtime.vfs'
