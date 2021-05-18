local stringify = require "stringify"
local config = {
    glb = {},
    texture = {},
    png = {},
    sc = {},
}

local function set_identity(ext, identity)
    local cfg = config[ext]
    if not cfg then
        error("invalid type: " .. ext)
    end
    cfg.setting = {
        identity = identity
    }
    cfg.arguments = stringify(cfg.setting)
end

local function get(ext)
    return assert(config[ext], "invalid path")
end

return {
    set_identity = set_identity,
    get = get,
}
