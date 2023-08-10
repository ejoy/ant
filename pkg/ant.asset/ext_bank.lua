local fs = require "filesystem"

local function read_file(filename)
    local f = assert(io.open(filename:localpath():string(), "rb"))
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