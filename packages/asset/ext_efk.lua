local lfs = require "filesystem.local"
local cr = import_package "ant.compile_resource"
local effekseer = require "effekseer"

local function read_file(filename)
    local f = assert(lfs.open(filename, "rb"))
    local c = f:read "a"
    f:close()
    return c
end
return {
    loader = function (filename)
        local c = read_file(cr.compile(filename))
        local dir = cr.compile(lfs.path(filename):remove_filename():string()):string()
        return {
            rawdata = c,
            filedir = dir
        }
    end,
    unloader = function (res)
    end
}