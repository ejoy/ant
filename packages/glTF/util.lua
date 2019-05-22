local util = {}; util.__index = util

local comptype_name_mapper = {
	[5120] = "BYTE",
	[5121] = "UNSIGNED_BYTE",
	[5122] = "SHORT",
	[5123] = "UNSIGNED_SHORT",
	[5125] = "UNSIGNED_INT",
	[5126] = "FLOAT",
}

local comptype_name_remapper = {}
for k, v in pairs(comptype_name_mapper) do
	comptype_name_remapper[v] = k
end

local type_count_mapper = {
	SCALAR = 1,
	VEC2 = 2,
	VEC3 = 3,
	VEC4 = 4,
	MAT2 = 4,
	MAT3 = 9,
	MAT4 = 16,
}

local type_count_remapper = {}
for k, v in pairs(type_count_mapper) do
	type_count_remapper[v] = k
end

local comptype_size_mapper = {
	[5120] = 1,
	[5121] = 1,
	[5122] = 2,
	[5123] = 2,
	[5125] = 4,
	[5126] = 4,
}

util.comptype_name_mapper 	= comptype_name_mapper
util.comptype_name_remapper = comptype_name_remapper
util.comptype_size_mapper	= comptype_size_mapper
util.type_count_mapper 		= type_count_mapper
util.type_count_remapper 	= type_count_remapper

function util.accessor(name, prim, meshscene)
	local accessors = meshscene.accessors
	local pos_accidx = assert(prim.attributes[name]) + 1
	return assert(accessors[pos_accidx])
end

function util.accessor_elemsize(accessor)
	local compcount = type_count_mapper[accessor.type]
	local compsize = comptype_size_mapper[accessor.componentType]

	return compcount * compsize
end

function util.num_vertices(prim, meshscene)
	local posacc = util.accessor("POSITION", prim, meshscene)
	return assert(posacc.count)
end

function util.start_vertex(prim, meshscene)
	local posacc = util.accessor("POSITION", prim, meshscene)
	local elemsize = util.accessor_elemsize(posacc)
	return posacc.byteOffset // elemsize
end

local function index_accessor(prim, meshscene)
	local accessors = meshscene.accessors
	return accessors[assert(prim.indices) + 1]
end

function util.num_indices(prim, meshscene)	
	return index_accessor(prim, meshscene).count
end

function util.start_index(prim, meshscene)
	local accessor = index_accessor(prim, meshscene)
	assert(accessor.type == "SCALAR")

	local elemsize = util.accessor_elemsize(accessor)
	return accessor.byteOffset // elemsize
end

function util.vertex_size(prim, meshscene)
	local vertexsize = 0
	for attribname in pairs(prim.attributes) do
		vertexsize = vertexsize + util.accessor_elemsize(util.accessor(attribname, prim, meshscene))
	end

	return vertexsize
end

function util.generate_accessor(bvidx, comptype, elemtype, offset, count, normalized)
	return {
		bufferView = bvidx,
		componentType = comptype_name_remapper[comptype],
		type = elemtype,
		byteOffset = offset,
		count = count,
		normalized = normalized,
	}
end

local target_mapper = {
	vertex = 34962,	--ARRAY_BUFFER
	index = 34963,	--ELEMENT_ARRAY_BUFFER
}

function util.generate_bufferview(bufferidx, offset, length, stride, target)
	return {
		buffer = bufferidx,
		byteOffset = offset,
		byteLength = length,
		byteStride = stride ~= 0 and stride or nil,
		target = target_mapper[target],
	}
end

function util.target(name)
	return target_mapper[name]
end

function util.generate_buffer(buffer, size)
	return {
		byteLength = size,
		extras = buffer,
	}
end

function util.generate_buffers(buffers)
	local b = {}
	for _, buf in ipairs(buffers) do
		b[#b+1] = util.generate_buffer(table.unpack(buf))
	end
	return b
end

return util