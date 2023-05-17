local ltask = require "ltask"
local EFKSERVER = ltask.queryservice "ant.efk|efk"

return {
    loader = function (filename)
        return {
            handle = ltask.call(EFKSERVER, "create", filename)
        }
    end,
    unloader = function (res)

    end
}