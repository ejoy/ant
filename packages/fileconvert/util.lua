local lfs = require "filesystem.local"
local datalist = require "datalist"

local util = {}; util.__index = util

function util.datalist(filepath)
	local f = assert(lfs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data)
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

function util.parse_embed_file(filepath)
    local fs = require "filesystem"
    if type(filepath) == "string" then
        filepath = fs.path(filepath)
    end
    local f = fs.open(filepath, "rb")
    if f == nil then
        error(string.format("could not open file:%s", filepath:string()))
        return
    end
    local magic = f:read(4)
    if magic ~= "res\0" then
        error(string.format("wrong format from file:%s",filepath:string()))
        return
    end

    local function read_pairs()
        local mark, len = f:read(4), f:read(4)
        return mark, string.unpack("<I4", len)
    end

    local luamark, lualen = read_pairs()
    assert(luamark == "lua\0")
    
    local luacontent = f:read(lualen)
    local luattable = {}
    local r, err = load(luacontent, "asset lua content", "t", luattable)
    if r == nil then
        log.error(string.format("parse file failed:%s, error:%s", filepath:string(), err))
        return nil
    end
    r()
    ----------------------------------------------------------------
    local binmark, binlen = read_pairs()
    assert(binmark == "bin\0")
    
    local binary = f:read(binlen)
    f:close()
    return luattable, binary
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