local json = import_package "ant.json"

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
	if padding_length == alignbytes then
		return data, length
	end
	assert(padding_length < alignbytes and padding_length > 0)
	return data..string.rep(align_char, padding_length), align_length
end

local function encode_chunk(f, datatype, data, length)
	local chunkinfo = ("<I4c4"):pack(length, datatype)
	f:write(chunkinfo)
	f:write(data)
end

local function decode(filename)
	local f <close> = assert(io.open(filename, "rb"))
	local header = f:read(12)
	local magic, version, _ = ("<c4I4I4"):unpack(header)
	assert(magic == "glTF")
	assert(version == 2)
	local info = json.decode(decode_chunk(f, "JSON"))
	local bin = decode_chunk(f, "BIN\0")
	assert(f:read(1) == nil)
	info.buffers[1].bin = bin
	return info
end

local function encode(filename, data)
	local f <close> = assert(io.open(filename:string(), "wb"))
	local jsondata = json.encode(data.info)
	local align_json, align_json_length = aligh_data(jsondata, 4, " ")
	local align_bin, align_bin_length = aligh_data(data.bin, 4, "\0")
	local headersize <const> = 12
	local chunk_headersize <const> = 8
	local size = headersize + chunk_headersize + align_json_length + chunk_headersize + align_bin_length
	f:write(("<c4I4I4"):pack("glTF", data.version, size))
	encode_chunk(f, "JSON", align_json, align_json_length)
	encode_chunk(f, "BIN\0", align_bin, align_bin_length)
end

return {
	decode = decode,
	encode = encode,
}
