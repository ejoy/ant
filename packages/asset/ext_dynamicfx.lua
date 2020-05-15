local fxloader = require "ext_fx".loader

return {
    loader = function (resdata)
        local filename = resdata.filename
        return fxloader(filename, resdata)
    end,
    unloader = function (resdata)
    end
}