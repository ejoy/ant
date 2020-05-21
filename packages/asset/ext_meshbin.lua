local utility = require "utility"
local thread = require "thread"

return {
    loader = function (filename)
        local c = utility.read_file(filename)
        return thread.unpack(c)
    end,
    unloader = function ()
    end,
}
