local lfs       = require "filesystem.local"

local util = {}; util.__index = util

function util.rawtable(filepath)
	local env = {}
	local r = assert(lfs.loadfile(filepath, "t", env))
	r()
	return env
end

function util.identify_info(identity)
    return identity:match "%.(%w+)%[([%s%w]+)%]_(%w+)$"
end

function util.write_embed_file(filepath, luacontent, binarys)
    local f = lfs.open(filepath, "wb")
    f:write("res\0")

    f:write("lua\0", string.pack("<I4", #luacontent), luacontent)

    local binarybytes = 0
    for _, b in ipairs(binarys) do
        binarybytes = binarybytes + #b
    end
    f:write("bin\0", string.pack("<I4", binarybytes), table.unpack(binarys))
    f:close()
end

function util.embed_file(filepath, luacontent, binarys)
    local utility = import_package "ant.utility.local"
	local stringify = utility.stringify
    local s = stringify(luacontent, true, true)
    util.write_embed_file(filepath, s, binarys)
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