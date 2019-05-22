local util = {}; util.__index = util

local gltf = import_package "ant.glTF"
local gltfutil = gltf.util

local bgfx = require "bgfx"
local declmgr = import_package "ant.render".declmgr

local function get_desc(name, accessor)
	local shortname, channel = declmgr.parse_attri_name(name)
	local comptype_name = gltfutil.comptype_name_mapper[accessor.componentType]

	return 	shortname .. 
			tostring(gltfutil.type_count_mapper[accessor.type]) .. 
			tostring(channel) .. 
			(accessor.normalized and "n" or "N") .. 
			"I" .. 
			gltfutil.decl_comptype_mapper[comptype_name]
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
	return attri_class
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

local function gen_indices_flags(accessor)
	local elemsize = gltfutil.accessor_elemsize(accessor)
	local flags = ""
	if elemsize == 4 then
		flags = 'd'
	end

	return flags
end

local function create_index_buffer(accessor, bufferviews, bindata, buffers)
	local bvidx = accessor.bufferView+1
	local bv = bufferviews[bvidx]

	if bindata then
		local start_offset = bv.byteOffset + 1
		local end_offset = start_offset + bv.byteLength

		bv.handle = bgfx.create_index_buffer({
			bindata, start_offset, end_offset,
		}, gen_indices_flags(accessor))
	else
		assert(buffers)
		local buffer = buffers[assert(bv.buffer)+1]
		local appdata = buffer.extras
		if buffer.extras then
			bv.handle = bgfx.create_index_buffer(appdata)
		else
			assert("not implement from uri")
		end
	end
	bv.byteOffset = 0
end

local function create_vertex_buffer(bv, declhandle, bindata, buffers)
	local start_offset = bv.byteOffset + 1
	local end_offset = start_offset + bv.byteLength
	if bindata then
		bv.handle = bgfx.create_vertex_buffer({
			"!", bindata, start_offset, end_offset
		}, declhandle)
	else
		assert(buffers)
		local buffer = buffers[assert(bv.buffer)+1]
		local appdata = buffer.extras
		if buffer.extras then
			bv.handle = bgfx.create_vertex_buffer(appdata, declhandle)
		else
			assert("not implement from uri")
		end
	end
	bv.byteOffset = 0
end

function util.init_scene(scene, bindata)
	local nodes, meshes, accessors, bufferviews = 
	scene.nodes, scene.meshes, scene.accessors, scene.bufferViews
	local buffers = scene.buffers

	local function create_buffers(scenenodes)
		for _, nodeidx in ipairs(scenenodes) do
			local node = nodes[nodeidx + 1]
			if node.children then
				create_buffers(node.children)
			end
			local meshidx = node.mesh
			if meshidx then
				local mesh = meshes[meshidx+1]
				for _, prim in ipairs(mesh.primitives) do
					local attribclass = classfiy_attri(prim.attributes, accessors)
					local decls = create_decl(attribclass)
					for bvidx, decl in pairs(decls)do
						create_vertex_buffer(bufferviews[bvidx+1], decl.handle, bindata, buffers)
					end

					local indices_accidx = prim.indices
					if indices_accidx then
						create_index_buffer(accessors[indices_accidx+1], bufferviews, bindata, buffers)
					end
				end
			end
		end
	end

	create_buffers(scene.scenes[scene.scene+1].nodes)

	return scene
end


local default_vbelem = "_30NIf"
local function correct_elem(elem)
	local len = #elem
	return len == #default_vbelem and 
			elem or 
			elem .. default_vbelem:sub(len+1)
end

return util