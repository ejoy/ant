local fs = require "filesystem"
local lfs = require "filesystem.local"
local cr = import_package "ant.compile_resource"
local effekseer = require "effekseer"

local function read_file(filename)
    local f = assert(lfs.open(filename:localpath(), "rb"))
    local c = f:read "a"
    f:close()
    return c
end
return {
    loader = function (filename)
        local path = fs.path(filename)
        local c = read_file(path)
        return {
            rawdata = c,
            filename = path:string()
        }
    end,
    unloader = function (res)
    end
}