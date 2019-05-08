local glTF = import_package "ant.glTF"
local glbloader = glTF.glb
local gltfloader = glTF.gltf

local gltf_converter = require "gltf.converter"

local componenttype_bgfxtype_maper = {
	[5120] = "", 		--"BYTE",
	[5121] = "UINT8", 	--"UNSIGNED_BYTE",
	[5122] = "INT16", 	--"SHORT",
	[5123] = "", 		--UNSIGNED_SHORT",
	[5125] = "", 		--"UNSIGNED_INT",
	[5126] = "FLOAT",	--"FLOAT"
}

local accessor_types = {
	SCALAR = 0,
	VEC2 = 1,
	VEC3 = 2,
	VEC4 = 3,
	MAT2 = 4,
	MAT3 = 5,
	MAT4 = 6,
}

local ENUM_ARRAY_BUFFER = 34962
local ENUM_ELEMENT_ARRAY_BUFFER = 34963


local function compile_bufferview(scene, bvidx)	
	local bufferview = scene.bufferviews[bvidx]
	return string.pack("<I4I4I4I4I4", 
		bvidx,
		bufferview.byteoffset, 
		bufferview.bytelength,
		bufferview.stride or 0,
		bufferview.target or ENUM_ARRAY_BUFFER)
end

local function compile_number_array(numberarray)
	local num = #numberarray
	for _=num+1, 16 do
		numberarray[#numberarray+1] = 0
	end
	assert(#numberarray == 16)
	return string.pack("<I4ffffffffffffffff", num, table.unpack(numberarray))
end


local function compile_accessor(scene, accessor)
	local bufferviews = scene.bufferviews
	return string.pack("<zI4I4I1I1I1I1zz", 
		compile_bufferview(scene, bufferviews[accessor.bufferview]), 
		accessor.byteoffset,
		accessor.componenttype,
		accessor.normalized and 1 or 0,
		accessor.count,
		accessor_types[accessor.type],
		0,	-- padding data for 4 bytes align
		compile_number_array(accessor.min or {}),
		compile_number_array(accessor.max or {})
	)
end

local attribname_mapper = {
	POSITION = 0,

	NORMAL = 1,
	TANGENT = 2,
	BITANGENT = 3,
	BINORMAL = 3,

	COLOR = 4,
	COLOR_0 = 4,
	COLOR_1 = 5,
	COLOR_2 = 6,
	COLOR_3 = 7,

	TEXCOORD_0 = 8,
	TEXCOORD_1 = 9,
	TEXCOORD_2 = 10,
	TEXCOORD_3 = 11,
	TEXCOORD_4 = 12,
	TEXCOORD_5 = 13,
	TEXCOORD_6 = 14,
	TEXCOORD_7 = 15,

	WEIGHT = 16,
	INDICES = 17,
}

local function compile_primitive(scene, primitive)
	local attributes = primitive.attributes

	local accessors = scene.accessors
	local a = {}

	for attribname, accessoridx in pairs(attributes) do
		local accessor = accessors[accessoridx]
		a[#a+1] = string.pack("<I4z", assert(attribname_mapper[attribname]), compile_accessor(scene, accessor))
	end

	local bin = string.pack("<I4z", #a, table.concat(a, ""))
	if primitive.indices then
		return bin .. string.pack("<z", compile_accessor(scene, accessors[primitive.indices]))
	end

	return bin
end

local function deserialize_primitve(seri_prim)

end

local function serialize_mesh_bindata(mesh_bindata)

end

local function deserialize_bufferviews(bvs)

end

local function write_bin_buffer(scene, prim, bin, buffers)
	local accessors = scene.accessors

	local offset = #bin
	for k, buffer in pairs(buffers)do
		local accessor
	end
end

return function (srcname, dstname, cfg)
	local version, jsondata, bindata = glbloader.decode(srcname)
	local scene = gltfloader.decode(jsondata)

	local scenes = scene.scenes
	local nodes = scene.nodes
	local meshes = scene.meshes	
	local accessors = scene.accessors
	local bufferviews = scene.bufferviews

	local mesh_buffers = {}
	local function process_node(scenenodes)
		for _, nodeidx in ipairs(scenenodes) do
			local node = nodes[nodeidx + 1]
			if node.children then
				process_node(node.children)
			end
			
			if node.mesh then
				local meshidx = node.mesh + 1
				local mesh = meshes[meshidx]
				local primitives = mesh.primitives
				local prim_buffers = {}				
				for idx, prim in ipairs(mesh.primitives) do
					local seri_prim = compile_primitive(scene, prim)
					local new_seri_prim, attrib_buffers = gltf_converter.fetch_buffers(seri_prim, bindata)					
					prim_buffers[idx] = attrib_buffers
					primitives[idx] = deserialize_primitve(new_seri_prim)
				end
				mesh_buffers[meshidx] = prim_buffers
			end
		end
	end

	process_node(scenes[scene.scene])


-- 	config = {
--     flags = {invert_normal = false, flip_uv = true, ib_32 = false},
--     layout = {'p3|n30nIf|T|b|t20|c40'},
-- }

	-- local function gen_attrib_bv_mapper(prim)
	-- 	local mapper = {}
	-- 	local attributes = prim.attributes
	-- 	for k, accidx in pairs(attributes) do
	-- 		local attribname = attribname_mapper[k]
	-- 		local accessor = accessors[accidx]
	-- 		mapper[attribname] = accessor.bufferview
	-- 	end

	-- 	return mapper
	-- end

	
	local function find_attrib_name(attribname_idx)
		for k, v in pairs(attribname_mapper)do
			if v == attribname_idx then
				return k
			end
		end
	end

	local function find_accessor_idx(attributes, attribname_idx)
		local name = find_attrib_name(attribname_idx)
		local accidx = attributes[name]
		return accidx or attributes[name .. "_0"]
	end

	
	local new_bindata_table = {}
	local bindata_offset = 0
	for meshidx, buffers in pairs(mesh_buffers) do
		local mesh = meshes[meshidx]
		for idx, prim in ipairs(mesh.primitives) do
			local prim_buffers = buffers[idx]
			--local bvmapper = gen_attrib_bv_mapper(prim)
			local rearrange_result = gltf_converter.rearrange_buffers(prim_buffers, cfg)
			local serilize_buffer_result = gltf_converter.to_string(rearrange_result.buffers)
			
			local new_bufferviews = deserialize_bufferviews(assert(rearrange_result.bufferviews_data))
			
			local startidx = #bufferviews + 1
			table.move(new_bufferviews, 1, #new_bufferviews, startidx, bufferviews)

			local attrib_binary_offsets = serilize_buffer_result.binary_offsets
			for attribname, info in pairs(rearrange_result.mapper) do
				local attrib_offset = attrib_binary_offsets[attribname]
				local accidx = assert(find_accessor_idx(prim.attributes, attribname))
				local accessor = accessors[accidx]
				local bvidx = info.bvidx + startidx
				accessor.bufferview = bvidx
				accessor.byteoffset = info.accessor_offset
				
				local bv = bufferviews[bvidx]
				bv.byteoffset = bindata_offset + attrib_offset
			end

			new_bindata_table[#new_bindata_table+1] = serilize_buffer_result.binary_buffers
			bindata_offset = #serilize_buffer_result.binary_buffers
		end
	end

	local new_bindata = table.concat(new_bindata_table, "")

	local newscene = {
		scene = scene.scene,
		scenes = scenes,
		nodes = nodes,
		meshes = meshes,
		accessors = accessors,
		bufferviews = bufferviews,
		buffers = {
			{bytelength = #new_bindata,}
		},
	}

	local new_jsondata = gltfloader.encode(newscene)
	glbloader.encode(dstname, version, new_jsondata, new_bindata)

end