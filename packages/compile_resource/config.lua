local bgfx = require "bgfx"
local platform = require "platform"
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

local texture_extensions = {
	direct3d11 	= "dds",
	direct3d12 	= "dds",
	metal 		= "ktx",
	vulkan 		= "ktx",
	opengl 		= "ktx",
}

local function init()
    local os = platform.OS:lower()
    local caps = bgfx.get_caps()
    local renderer = caps.rendererType:lower()
    local texture = assert(texture_extensions[renderer])
    set_setting("glb", {})
    set_setting("sc", {
        os = os,
        renderer = renderer,
        hd = caps.homogeneousDepth and true or nil,
        obl = caps.originBottomLeft and true or nil,
    })
    set_setting("texture", {os=os, ext=texture})
    set_setting("png", {os=os, ext=texture})
end


return {
    init = init,
    set_setting = set_setting,
    get = get,
}
