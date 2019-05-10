
local function chunk(f, checktype)
    local header = f:read(8)
    local length, type = ("<I4c4"):unpack(header)
    assert(checktype == type)
    return f:read(length)
end

local function write_chunk(f, datatype, data)
	local length = #data
	local chunkinfo = string.pack("<I4c4", length, datatype)
	f:write(chunkinfo)
	f:write(data)
end

local function decode(filename)
    local f = assert(io.open(filename, "rb"))
    local header = f:read(12)
    local magic, version, _ = ("<c4I4I4"):unpack(header)
    assert(magic == "glTF")
    local json = chunk(f, "JSON")
	local bin = chunk(f, "BIN\0")
	assert(f:read(1) == nil)
    f:close()
    return version, json, bin
end

local function encode(filename, version, json, bindata)
	local f = assert(io.open(filename, "wb"))
	local header = string.pack("<c4I4I4", "glTF", version, 0)
	f:write(header)
	write_chunk(f, "JSON", json)
	write_chunk(f, "BIN\0", bindata)	
	f:close()
end

return {
	decode = decode,
	encode = encode,
}
