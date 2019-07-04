local jsonDecode = require "json".decode
local jsonEncode = require "json".encode

local function decode_chunk(f, checktype)
    local header = f:read(8)
    local length, type = ("<I4c4"):unpack(header)
    assert(checktype == type)
    return f:read(length)
end

local function aligh_data(data, alignbytes, align_char)
	local length = #data	
	local align_length = ((length // alignbytes) + 1) * alignbytes
	local padding_length = align_length - length

	if padding_length < alignbytes then
		local t = {data}
		for _=1, padding_length do
			t[#t+1] = align_char
		end
		return table.concat(t, ""), align_length
	end

	assert(padding_length > 0)
	return data, length
end

local function encode_chunk(f, datatype, data, length)
	local chunkinfo = string.pack("<I4c4", length, datatype)
	f:write(chunkinfo)
	f:write(data)
end

local function decode_from_filehandle(f)
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

local function decode(filename)
    local f = assert(io.open(filename, "rb"))
	return decode_from_filehandle(f)
end

local function encode(filename, data)
	local f = assert(io.open(filename, "wb"))
	local headersize = 12
	local chunk_headersize = 8

	local jsondata = jsonEncode(data.info)
	local align_json, align_json_length = aligh_data(jsondata, 4, " ")
	local align_bindata, align_bindata_length = aligh_data(data.bin, 4, "\0")

	local header = string.pack("<c4I4I4", "glTF", data.version, 
		headersize + 
		chunk_headersize + align_json_length + 
		chunk_headersize + align_bindata_length)
	f:write(header)
	encode_chunk(f, "JSON", align_json, align_json_length)
	encode_chunk(f, "BIN\0", align_bindata, align_bindata_length)
	f:close()
end

return {
	decode = decode,
	decode_from_filehandle = decode_from_filehandle,
	encode = encode,
}
