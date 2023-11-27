local bgfx      = require "bgfx"
local platform  = require "bee.platform"
local vfs       = require "vfs"

local function init()
    local caps = bgfx.get_caps()
    local renderer = caps.rendererType:lower()
    vfs.resource_setting(("%s-%s"):format(platform.os, renderer))
end

local function compile(pathstring)
    return vfs.realpath(pathstring)
end

return {
    init = init,
    compile = compile,
}
