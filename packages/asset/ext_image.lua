local img = require "image"
local fs = require "filesystem"
return {
    loader = function (filename, setting)
        if setting.compile then
            local texloader = require "ext_texture"
            return texloader.loader(filename)
        end
        local f = fs.open(fs.path(filename), "rb")
        local c = f:read "a"
        f:close()
        return {
            handle = img.parse(c, setting.format)
        }
    end,
    unloader = function ()
    end,
}