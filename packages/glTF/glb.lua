local jsonDecode = require "json".decode
local jsonEncode = require "json".encode

local function decode_chunk(f, checktype)
    local header = f:read(8)
    local length, type = ("<I4c4"):unpack(header)
    assert(checktype == type)
    return f:read(length)
end

local function decode(filename)
    local f = assert(io.open(filename, "rb"))
    local header = f:read(12)
    local magic, version, _ = ("<c4I4I4"):unpack(header)
    assert(magic == "glTF")
    local json = decode_chunk(f, "JSON")
	local bin = decode_chunk(f, "BIN\0")
	assert(f:read(1) == nil)
    f:close()
    return {
        version = version,
        info = jsonDecode(json),
        bin = bin
    }
end

local function encode_chunk(f, checktype, data)
    f:write(("<I4"):pack(#data))
    f:write(checktype)
    f:write(data)
end

local function encode(filename, glb)
    local json = jsonEncode(glb.info)
    local f = assert(io.open(filename, "wb"))
    f:write("glTF")
    f:write(("<I4"):pack(glb.version))
    local length = #json + #glb.bin + 28
    f:write(("<I4"):pack(length))
    encode_chunk(f, "JSON", json)
    encode_chunk(f, "BIN\0", glb.bin)
    f:close()
end

return {
    decode = decode,
    encode = encode,
}
