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
        return {
            rawdata = c
        }
    end,
    unloader = function (res)
    end
}