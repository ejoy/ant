local mgr = require "texture_mgr"

return {
    loader = function (name)
        return mgr.create(name)
    end,
    reloader = function (name, _, block)
        return mgr.reload(name, block)
    end,
}
