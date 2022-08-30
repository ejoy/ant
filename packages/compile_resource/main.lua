local lfs       = require "filesystem.local"
local cm        = require "compile"
local bgfx      = require "bgfx"
local platform  = require "platform"
local vfs       = require "vfs"
local stringify = require "stringify"

if not __ANT_RUNTIME__ then
    require "editor.compile"
end

local function read_file(filename)
    local f = assert(lfs.open(cm.compile(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

local texture_extensions = {
    noop        = platform.OS == "WINDOWS" and "dds" or "ktx",
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
    vfs.resource_setting("model", stringify {})
    vfs.resource_setting("glb", stringify {})
    vfs.resource_setting("material", stringify {
        os = os,
        renderer = renderer,
        hd = caps.homogeneousDepth and true or nil,
        obl = caps.originBottomLeft and true or nil,
    })
    vfs.resource_setting("texture", stringify {os=os, ext=texture})
    vfs.resource_setting("png", stringify {os=os, ext=texture})
end

return {
    init        = init,
    read_file   = read_file,
    compile     = cm.compile,
    compile_path= cm.compile_path,
    compile_dir = cm.compile_dir,
}
