local lfs = require "filesystem.local"
local thread = require "thread"
local compile_resource = require "compile".compile

local util = {}; util.__index = util

function util.identify_info(identity)
    return identity:match "%.(%w+)%[([%s%w]+)%]_(%w+)$"
end

function util.write_embed_file(filepath, ...)
    local f = assert(lfs.open(filepath, "wb"))
    f:write(thread.pack(...))
    f:close()
end

function util.read_embed_file(filepath)
    local fs = require "filesystem"
    if type(filepath) == "string" then
        filepath = fs.path(filepath)
    end

    local realpath = compile_resource(filepath:localpath())
    local f <close> = lfs.open(lfs.path(realpath), "rb")
    if f == nil then
        error(string.format("could not open file:%s", filepath:string()))
        return
    end
    return thread.unpack(f:read "a")
end

util.shadertypes = {
	NOOP       = "d3d9",
	DIRECT3D9  = "d3d9",
	DIRECT3D11 = "d3d11",
	DIRECT3D12 = "d3d11",
	GNM        = "pssl",
	METAL      = "metal",
	OPENGL     = "glsl",
	OPENGLES   = "essl",
	VULKAN     = "spirv",
}

return util
