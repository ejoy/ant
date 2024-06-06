local mgr = require "texture_mgr"

return {
    loader = function (name)
        return mgr.create(name)
    end,
    reloader = function (name)
        return mgr.reload(name)
    end,
}
