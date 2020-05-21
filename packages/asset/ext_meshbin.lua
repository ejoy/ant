local fs_rt = import_package "ant.utility".fs_rt
local thread = require "thread"
return {
    loader = function (filename)
        local c = fs_rt.read_file(filename)
        return thread.unpack(c)
    end,
    unloader = function ()
    end,
}