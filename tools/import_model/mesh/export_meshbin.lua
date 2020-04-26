local glb_cvt	= require "mesh.glb_convertor"

local gltfutil	= require "glTF.util"
local declmgr	= require "render.vertexdecl_mgr"
local fs_util	= require "utility.fs_util"

local math3d	= require "math3d"
local thread	= require "thread"

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

local function which_layout_type(name, layouts)
	for _, layout in ipairs(layouts) do
		if layout.format == name then
			return layout.type or "static"
		end
	end
	return "static"
end

local function create_decl(attri_class, layouts)
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
			type = assert(which_layout_type(declname, layouts)),
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

local function fetch_ib_info(bv, bufferflag, bindata, buffers)
	if bindata then
		local start_offset = bv.byteOffset + 1
		return {
			type = "static",
			value = bindata,
			start = start_offset,
			num = bv.byteLength,
			flag = bufferflag,
		}
	end

	assert(buffers)
	local buffer = buffers[assert(bv.buffer)+1]
	local appdata = buffer.extras
	if buffer.extras then
		return {
			type = "static",
			value = appdata[1],
			start = appdata[2],
			num = appdata[3] - appdata[2],
			flag = bufferflag,
		}
	end

	assert("not implement from uri")
end

local function fetch_vb_info(bv, declinfo, bindata, buffers)
	local buffertype = declinfo.type
	local declname = declinfo.declname

	if bindata then
		local start_offset = bv.byteOffset + 1
		return {
			type = buffertype,
			declname = declname,
			value 	= bindata,
			start 	= start_offset,
			num 	= bv.byteLength,
		}
	end

	assert(buffers)
	local buffer = buffers[assert(bv.buffer)+1]
	local appdata = buffer.extras
	if buffer.extras then
		assert(appdata[1] == "!")
		return {
			type = buffertype,
			declname = declname,
			value = appdata[2],
			start = appdata[3],
			num = appdata[4] - appdata[3],
		}
	end

	assert("not implement from uri")
end

local function create_prim_bounding(meshscene, prim)	
	local posacc = meshscene.accessors[assert(prim.attributes.POSITION)+1]
	if posacc.min then
		assert(#posacc.min == 3)
		assert(#posacc.max == 3)
		local bounding = {
			aabb = {posacc.min, posacc.max}
		}
		prim.bounding = bounding
		return bounding
	end
end

local function node_matrix(node)
	if node.matrix then
		return math3d.matrix(node.matrix)
	end

	if node.scale or node.rotation or node.translation then
		return math3d.matrix{s=node.scale, r=node.rotation, t=node.translation}
	end
end

local function calc_node_transform(node, parentmat)
	local nodetrans = node_matrix(node)
	if nodetrans then
		return parentmat and math3d.mul(parentmat, nodetrans) or nodetrans
	end
	return parentmat
end

local function fetch_inverse_bind_matrices(gltfscene, skinidx, bindata)
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

local function to_aabb(meshaabb)
	return {
		aabb = {
			math3d.tovalue(math3d.index(meshaabb, 1)),
			math3d.tovalue(math3d.index(meshaabb, 2))
		}
	}
end

local function get_obj_name(obj, idx, defname)
	if obj.name then
		return obj.name
	end

	return defname .. idx
end

local function export_meshbin(gltfscene, bindata, config)
	local layouts 		= config.layouts
	for _, l in ipairs(layouts) do
		l.format = declmgr.correct_layout(l.format)
	end
	local scene_scalemat = math3d.ref(math3d.matrix{s=gltfscene.scenescale})

	local bvcaches = {}

	local function create_mesh_scene(gltfnodes, parentmat, scenegroups)
		for _, nodeidx in ipairs(gltfnodes) do
			local node = gltfscene.nodes[nodeidx + 1]
			local nodetrans = calc_node_transform(node, parentmat)

			if node.children then
				create_mesh_scene(node.children, nodetrans, scenegroups)
			end

			local meshidx = node.mesh
			local meshname
			if meshidx then
				local mesh = gltfscene.meshes[meshidx+1]
				meshname = get_obj_name(mesh, meshidx, "mesh")

				if scenegroups[meshname] == nil then
					local meshnode = {
						transform = nodetrans and math3d.tovalue(nodetrans) or nil,
						inverse_bind_matries = fetch_inverse_bind_matrices(gltfscene, node.skin, bindata),
					}
	
					local meshaabb = math3d.aabb()
	
					for _, prim in ipairs(mesh.primitives) do
						local group = {
							mode = prim.mode,
							material = prim.material,
						}
						local attribclass 	= classfiy_attri(prim.attributes, gltfscene.accessors)
						local decls 		= create_decl(attribclass, layouts)
	
						local values = {}
						for bvidx, declinfo in pairs(decls) do
							local vbcache = bvcaches[bvidx+1]
							local bv = gltfscene.bufferViews[bvidx+1]
							if vbcache == nil then
								vbcache = fetch_vb_info(bv, declinfo, bindata, gltfscene.buffers)
								bvcaches[bvidx+1] = vbcache
							end
							values[#values+1] = vbcache
						end
	
						group.vb = {
							values 	= values,
							start 	= 0,
							num 	= gltfutil.num_vertices(prim, gltfscene),
						}
	
						local indices_accidx = prim.indices
						if indices_accidx then
							local idxacc = gltfscene.accessors[indices_accidx+1]
							local bv = gltfscene.bufferViews[idxacc.bufferView+1]
	
							local cache = bvcaches[idxacc.bufferView+1]
							if cache == nil then
								cache = fetch_ib_info(bv, gen_indices_flags(idxacc), bindata, gltfscene.buffers)
								bvcaches[idxacc.bufferView+1] = cache
							end
	
							group.ib = {
								value 	= cache,
								start 	= 0,
								num 	= idxacc.count,
							}
						end
	
						local bb = create_prim_bounding(gltfscene, prim)
						if bb then
							group.bounding = bb
							meshaabb = math3d.aabb_merge(meshaabb, math3d.aabb(bb.aabb[1], bb.aabb[2]))
						end
	
						meshnode[#meshnode+1] = group
					end
	
					if math3d.aabb_isvalid(meshaabb) then
						meshnode.bounding = {aabb = to_aabb(meshaabb)}
					end
	
					scenegroups[meshname] = meshnode
				end
			end
		end
	end

	local meshscene = {
		scenelods = gltfscene.scenelods,
		scenescale = gltfscene.scenescale,
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
		local scenename = get_obj_name(s, sceneidx, "scene")
		create_mesh_scene(s.nodes, scene_scalemat, scene)
		scenes[scenename] = scene
	end

	local def_sceneidx = gltfscene.scene+1
	meshscene.default_scene = get_obj_name(gltfscene.scenes[def_sceneidx], def_sceneidx, "scene")
	return meshscene
end

return function (glbscene, bindata, outfile, cfg)
	local new_glbscene, new_bindata = glb_cvt(glbscene, bindata, cfg)
	local result = export_meshbin(new_glbscene, new_bindata, cfg)

	if result then
		fs_util.write_file(outfile, thread.pack(result))
		return true
	end

	return nil, "convert file failed"
end