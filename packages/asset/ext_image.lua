local img = require "image"
local fs = require "filesystem"
return {
    loader = function (filename)
        local f = fs.open(fs.path(filename), "rb")
        local c = f:read "a"
        f:close()
        return img.parse(c)
    end,
    unloader = function ()
    end,
}