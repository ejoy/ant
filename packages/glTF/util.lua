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

local decl_comptype_mapper = {
	BYTE 			= "u",
	UNSIGNED_BYTE 	= "u",
	SHORT 			= "i",
	UNSIGNED_SHORT 	= "i",
	UNSIGNED_INT 	= "",	-- bgfx not support
	FLOAT 			= "f",
}

local decl_comptype_remapper = {
	u = "UNSIGNED_BYTE",
	i = "UNSIGNED_SHORT",
	f = "FLOAT",
}

util.comptype_name_mapper 	= comptype_name_mapper
util.comptype_name_remapper = comptype_name_remapper
util.comptype_size_mapper	= comptype_size_mapper
util.type_count_mapper 		= type_count_mapper
util.type_count_remapper 	= type_count_remapper
util.decl_comptype_mapper	= decl_comptype_mapper
util.decl_comptype_remapper = decl_comptype_remapper

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

function util.generate_index_accessor(bvidx, offset, count, int32)
	return util.generate_accessor(bvidx, int32 and "UNSIGNED_INT" or "UNSIGNED_SHORT", "SCALAR", offset, count, false)
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

function util.generate_index_bufferview(bufferidx, offset, length)
	return util.generate_bufferview(bufferidx, offset, length, 0, "index")
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

local function elem_size(t, c)
	return comptype_size_mapper[comptype_name_remapper[t]] * c
end

function util.create_vertex_info(decllayout, namemapper, num_vertices, bvidx, accessors, attributes)	
	local offset = 0
	for elem in decllayout:gmatch "%w+" do
		local shortname = elem:sub(1, 1)
		local attribname = namemapper[shortname]
		attributes[attribname] = #accessors

		local elemtype = elem:sub(6, 6)			
		local elemcount = tonumber(elem:sub(2, 2))
		local normalized = elem:sub(4, 4) == "n"
		local ct = decl_comptype_remapper[elemtype]
		accessors[#accessors+1] = util.generate_accessor(bvidx, 
			ct,	type_count_remapper[elemcount],
			offset,
			num_vertices,
			normalized)
		offset = offset + elem_size(ct, elemcount)
	end
end

function util.default_mesh_handle()
	return {
		scene = 0,
		scenes = {{nodes={0}}},
		nodes = {{mesh=0}},
		meshes = {},
	}
end

function util.create_mesh_handle(primitive, accessors, bufferviews, buffers)
	local scene = util.default_mesh_handle()
	local m = scene.meshes
	m[#m+1] = {primitives={primitive}}
	scene.accessors = accessors
	scene.bufferViews = bufferviews
	scene.buffers = buffers
	return scene
end

return util