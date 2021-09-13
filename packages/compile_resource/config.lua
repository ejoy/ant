local stringify = require "stringify"
local config = {
    glb = {setting={},arguments=""},
    texture = {setting={},arguments=""},
    png = {setting={},arguments=""},
    sc = {setting={},arguments=""},
}

local function set_setting(ext, setting)
    local cfg = config[ext]
    if not cfg then
        error("invalid type: " .. ext)
    end
    cfg.setting = setting
    cfg.arguments = stringify(cfg.setting)
end

local function get(ext)
    return assert(config[ext], "invalid path")
end

return {
    set_setting = set_setting,
    get = get,
}
