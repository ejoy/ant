local lfs       = require "filesystem.local"
local cm        = require "compile"
local bgfx      = require "bgfx"
local platform  = require "platform"
local vfs       = require "vfs"

if not __ANT_RUNTIME__ then
    require "editor.compile"
end

local function read_file(filename)
    local f = assert(lfs.open(cm.compile(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

local function sortpairs(t)
    local sort = {}
    for k in pairs(t) do
        sort[#sort+1] = k
    end
    table.sort(sort)
    local n = 1
    return function ()
        local k = sort[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function stringify(t)
    local s = {}
    for k, v in sortpairs(t) do
        s[#s+1] = k.."="..tostring(v)
    end
    return table.concat(s, "&")
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
}
