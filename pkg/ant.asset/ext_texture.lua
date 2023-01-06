local mgr = require "texture_mgr"

return {
    loader = mgr.create,
    unloader = mgr.destroy,
}
