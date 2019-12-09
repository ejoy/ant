local gltf = import_package "ant.glTF"
local gltfutil = gltf.util
local glbloader = gltf.glb

local bgfx = require "bgfx"
local declmgr = import_package "ant.render".declmgr
local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util

local mathbaselib = require "math3d.baselib"

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

local function which_layout_type(name, layout, layout_types)
	if layout_types then
		for i=1, #layout do
			if layout[i] == name then
				return layout_types[i]
			end
		end
	end
	return "static"
end

local function create_decl(attri_class, layout, layout_types)
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
		decls[bvidx] = {
			declname = declname,
			type = assert(which_layout_type(declname, layout, layout_types)),
		}
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

local function create_ib_handle(bv, bufferflag, bindata, buffers)
	if bindata then
		local start_offset = bv.byteOffset + 1
		local end_offset = start_offset + bv.byteLength
		local value = bindata:sub(start_offset, end_offset)
		return bgfx.create_index_buffer({
			bindata, start_offset, end_offset
		}, bufferflag)
	end

	assert(buffers)
	local buffer = buffers[assert(bv.buffer)+1]
	local appdata = buffer.extras
	if buffer.extras then
		return bgfx.create_index_buffer(appdata)
	end

	assert("not implement from uri")
end

local function create_vb_handle(bv, declinfo, bindata, buffers)
	local buffertype = declinfo.type
	local declname = declinfo.declname
	local start_offset = bv.byteOffset + 1
	local end_offset = start_offset + bv.byteLength

	if bindata then
		if buffertype == "dynamic" then
			local value = bindata:sub(start_offset, end_offset-1)
			return nil, {
				data = value,
				declname = declname,
			}
		end
		
		return bgfx.create_vertex_buffer(
			{"!", bindata, start_offset, end_offset,}, declmgr.get(declname).handle
		)
	end

	assert(buffers)
	local buffer = buffers[assert(bv.buffer)+1]
	local appdata = buffer.extras
	if buffer.extras then
		if buffertype == "dynamic" then
			return nil, {
				data = appdata,
				declname = declname
			}
		end

		return bgfx.create_vertex_buffer(appdata, declmgr.get(declname).handle)
	end

	assert("not implement from uri")
end

local function create_prim_bounding(meshscene, prim)	
	local posacc = meshscene.accessors[assert(prim.attributes.POSITION)+1]
	if posacc.min then
		assert(#posacc.min == 3)
		assert(#posacc.max == 3)
		local bounding = mathbaselib.new_bounding(ms, assert(posacc.min), assert(posacc.max))
		prim.bounding = bounding
		return bounding
	end
end

local function node_matrix(node)
	if node.matrix then
		return ms:matrix(node.matrix)
	end

	if node.scale or node.rotation or node.translation then
		return ms:srtmat(node.scale, node.rotation, node.translation)
	end
end

local function calc_node_transform(node, parentmat)
	local nodetrans = node_matrix(node)
	return nodetrans and ms(parentmat, nodetrans, "*P") or parentmat
end

local function fetch_inverse_bind_poses(gltfscene, skinidx, bindata)
	if skinidx then
		local skin 		= gltfscene.skins[skinidx+1]
		local ibm_idx 	= skin.inverseBindMatrices
		local ibm 		= gltfscene.accessors[ibm_idx+1]
		local ibm_bv 	= gltfscene.bufferViews[ibm.bufferView+1]

		local start_offset = ibm_bv.byteOffset + 1
		local end_offset = start_offset + ibm_bv.byteLength

		return {
			num		= ibm.count,
			joints 	= skin.joints,
			value 	= bindata:sub(start_offset, end_offset-1),
		}
	end
end

local function init_scene(gltfscene, bindata, config)
	local layout 		= config.config.layout
	for i=1, #layout do
		layout[i] = declmgr.correct_layout(layout[i])
	end
	local layout_types 	= config.config.layout_types

	local bvhandles = {}
	local function create_mesh_scene(gltfnodes, parentmat, scenegroups)
		for _, nodeidx in ipairs(gltfnodes) do
			local node = gltfscene.nodes[nodeidx + 1]
			local nodetrans = calc_node_transform(node, parentmat)

			if node.children then
				create_mesh_scene(node.children, nodetrans, scenegroups)
			end

			local meshidx = node.mesh
			if meshidx then
				local meshnode = {
					nodename = node.name,
					transform = ms:ref "matrix" (nodetrans),
					inverse_bind_poses = fetch_inverse_bind_poses(gltfscene, node.skin, bindata),
				}
				local mesh = gltfscene.meshes[meshidx+1]
				local meshbounding = mathbaselib.new_bounding(ms)

				meshnode.meshname = mesh.name

				for _, prim in ipairs(mesh.primitives) do
					local group = {
						mode = prim.mode,
						material = prim.material,
					}
					local attribclass 	= classfiy_attri(prim.attributes, gltfscene.accessors)
					local decls 		= create_decl(attribclass, layout, layout_types)

					local handles, values = {}, {}
					for bvidx, declinfo in pairs(decls) do
						local bvcache = bvhandles[bvidx+1]
						local bv = gltfscene.bufferViews[bvidx+1]
						if bvcache == nil then
							local handle, value = create_vb_handle(bv, declinfo, bindata, gltfscene.buffers)
							bvcache = {
								handle = handle or false,	-- need occupy an array slot
								value = value or false,
							}

							bvhandles[bvidx+1] = bvcache
						end
						handles[#handles+1] = bvcache.handle
						values[#values+1] = bvcache.value
					end

					group.vb = {
						handles = handles,
						values = values,
						start = 0,
						num = gltfutil.num_vertices(prim, gltfscene),
					}

					local indices_accidx = prim.indices
					if indices_accidx then
						local idxacc = gltfscene.accessors[indices_accidx+1]
						local bv = gltfscene.bufferViews[idxacc.bufferView+1]

						local cache = bvhandles[idxacc.bufferView+1]
						if cache == nil then
							local handle = create_ib_handle(bv, gen_indices_flags(idxacc), bindata, gltfscene.buffers)
							cache = {
								handle = handle
							}
							bvhandles[idxacc.bufferView+1] = cache
						end

						group.ib = {
							handle = cache.handle,
							value = cache.value,
							start = 0,
							num = idxacc.count,
						}
					end

					local bb = create_prim_bounding(gltfscene, prim)
					if bb then
						group.bounding = bb
						meshbounding:merge(bb)
					end

					meshnode[#meshnode+1] = group
				end

				if meshbounding:isvalid() then
					meshnode.boundings = meshbounding
				end

				scenegroups[#scenegroups+1] = meshnode
			end
		end
	end

	local meshscene = {
		sceneidx = gltfscene.scene+1,
		scenelods = gltfscene.scenelods,
		sccenescale = gltfscene.scenescale,
		scenes = {}
	}

	if meshscene.scenelods then
		for idx, lod in ipairs(meshscene.scenelods) do
			meshscene.scenelods[idx] = lod + 1
		end
	end
	local scenes = meshscene.scenes
	for sceneidx, s in ipairs(gltfscene.scenes) do
		local scene = {}
		create_mesh_scene(s.nodes, ms(mu.srt(), "P"), scene)
		scenes[sceneidx] = scene
	end

	return meshscene
end

local function file_wrapper(meshcontent)
	local startiter = 1
	local count = #meshcontent
	return {
		read = function (_, numbytes)
			local enditer = startiter - 1 + numbytes
			if enditer <= count then
				local c = meshcontent:sub(startiter, enditer)
				startiter = startiter + numbytes
				return c
			end
		end,
		close = function ()
		end,
	}
end

return function (meshcontent, config)
	local glbdata = glbloader.decode_from_filehandle(file_wrapper(meshcontent))
	return init_scene(glbdata.info, glbdata.bin, config)
end