local gltf = import_package "ant.glTF"
local gltfutil = gltf.util
local bgfx = require "bgfx"
local declmgr = import_package "ant.render".declmgr

local comptype_shortname_mapper = {
	BYTE 			= "u",
	UNSIGNED_BYTE 	= "u",
	SHORT 			= "i",
	UNSIGNED_SHORT 	= "i",
	UNSIGNED_INT 	= "",
	FLOAT 			= "f",
}

local function get_desc(name, accessor)
	local shortname, channel = declmgr.parse_attri_name(name)
	local comptype_name = gltfutil.comptype_name_mapper[accessor.componentType]

	return 	shortname .. 
			gltfutil.type_count_mapper[accessor.type] .. 
			channel .. 
			accessor.normalized and "n" or "N" .. 
			"I" .. 
			comptype_shortname_mapper[comptype_name]	
end

local function classfiy_attri(attributes, accessors)
	local attri_class = {}
	for attriname, accidx in pairs(attributes) do
		local acc = accessors[accidx+1]
		local bvidx = acc.bufferView
		local class = attri_class[bvidx]
		if class == nil then
			class = {}
			attri_class[bvidx] = class
		end

		class[attriname] = acc
	end
end

local function create_decl(attri_class)
	local decls = {}
	for bvidx, class in pairs(attri_class) do
		local sorted_class = {}
		for attriname in pairs(class) do
			sorted_class[#sorted_class+1] = attriname
		end

		table.sort(sorted_class, function (lhs, rhs)
			local lhsacc, rhsacc = class[lhs], class[rhs]
			return lhsacc.byteOffset < rhsacc.byteOffset
		end)

		local decl_descs = {}
		for _, attriname in ipairs(sorted_class) do
			local acc = class[attriname]
			decl_descs[#decl_descs+1] = get_desc(attriname, acc)
		end

		local declname = table.concat(decl_descs, "|")
		decls[bvidx] = declmgr.get(declname)
	end

	return decls
end

return function (meshfile)
	local glbloader = gltf.glb
	local gltfloader = gltf.gltf
	local _, jsondata, bindata = glbloader.decode_from_filehandle(meshfile)
	local scene = gltfloader.decode(jsondata)

	local nodes, meshes, accessors, bufferviews = 
	scene.nodes, scene.meshes, scene.accessors, scene.bufferViews

	local function create_buffers(scenenodes)
		for _, nodeidx in ipairs(scenenodes) do
			local node = nodes[nodeidx + 1]
			if node.children then
				create_buffers(node.children)
			end
			local meshidx = assert(node.mesh)
			local mesh = meshes[meshidx]
			for _, prim in ipairs(mesh.primitives) do
				local attribclass = classfiy_attri(prim.attributes, accessors)
				local decls = create_decl(attribclass)
				for bvidx, decl in pairs(decls)do
					local bv = bufferviews[bvidx + 1]
					bv.handle = bgfx.create_vertex_buffer(decl, {
						"!", bindata, bv.byteOffset, bv.byteLength,
					})
					bv.byteOffset = 0
				end

				local indices_accessor = accessors[prim.indices+1]
				local indices_bvidx = indices_accessor.bufferView+1
				local indices_bv = bufferviews[indices_bvidx]
				indices_bv.handle = bgfx.create_index_buffer{
					bindata, indices_bv.byteOffset, indices_bv.byteLength
				}
				indices_bv.byteOffset = 0
			end
		end
	end

	create_buffers(scene.scenes[scene.scene+1])
	return scene
end