
local gltfpkg   = import_package "ant.glTF"
local gltfutil	= gltfpkg.util
local renderpkg = import_package "ant.render"
local declmgr	= renderpkg.declmgr

local sort_pairs = require "sort_pairs"

local math3d	= require "math3d"

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
			inverse_bind_matrices = {
				num		= ibm.count,
				value 	= bindata:sub(start_offset, end_offset-1),
			},
			joints 	= skin.joints,
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

local default_layouts = {
	POSITION	= 1,
	NORMAL 		= 1,
	TANGENT 	= 1,
	BITANGENT 	= 1,

	JOINTS_0 	= 2,
	WEIGHTS_0 	= 2,

	COLOR_0		= 3,
	COLOR_1		= 3,
	COLOR_2		= 3,
	COLOR_3		= 3,
	TEXCOORD_0 	= 3,
	TEXCOORD_1 	= 3,
	TEXCOORD_2 	= 3,
	TEXCOORD_3 	= 3,
	TEXCOORD_4 	= 3,
	TEXCOORD_5 	= 3,
	TEXCOORD_6 	= 3,
	TEXCOORD_7 	= 3,
}

local function fetch_attri_buffers(gltfscene, gltfbin, attributes)
	local attribclasses = {}
	for attribname, accidx in pairs(attributes) do
		local which_layout = default_layouts[attribname]
		if which_layout == nil then
			error(("invalid attrib name:%s"):format(attribname))
		end
		local attriclass = attribclasses[which_layout]
		if attriclass == nil then
			attriclass = {}
			attribclasses[which_layout] = attriclass
		end

		attriclass[#attriclass+1] = {attribname, accidx}
	end

	local accessors = gltfscene.accessors
	local bufferviews = gltfscene.bufferViews
	local attribuffers = {}
	local numv = accessors[attributes.POSITION+1].count
	for idx, attribclass in sort_pairs(attribclasses) do
		
		local declname = {}
		local cacheclass = {}
		for _, info in ipairs(attribclass) do
			local attribname, accidx = info[1], info[2]
			local acc = accessors[accidx+1]
			local bv = bufferviews[acc.bufferView+1]

			local acc_offset = acc.byteOffset or 0
			local bv_offset = bv.byteOffset or 0

			local elemsize = gltfutil.accessor_elemsize(acc)
			cacheclass[#cacheclass+1] = {acc_offset, bv_offset, elemsize, bv.byteStride or elemsize}
			declname[#declname+1] = get_desc(attribname, acc)
		end

		local buffer = {}
		for ii=0, numv-1 do
			for jj=1, #cacheclass do
				local c = cacheclass[jj]
				local acc_offset, bv_offset, elemsize, stride = c[1], c[2], c[3], c[4]
				local elemoffset = bv_offset + ii * stride + acc_offset + 1
				buffer[#buffer+1] = gltfbin:sub(elemoffset, elemoffset + elemsize - 1)
			end
		end

		local bindata = table.concat(buffer, "")
		attribuffers[idx] = {
			start 	= 1,
			declname= table.concat(declname, "|"),
			value 	= bindata,
			num 	= #bindata,
		}
	end

	return attribuffers
end

local function find_skin_root_idx(scene, skin)
	local joints = skin.joints
	if joints == nil then
		error(string.format("invalid mesh, skin node must have joints"))
	end

	if skin.skeleton then
		return skin.skeleton;
	end

	local parents = {}
	for _, nodeidx in ipairs(joints) do
		local c = scene.nodes[nodeidx+1].children
		if c then
			for _,  cnodeidx in ipairs(c) do
				parents[cnodeidx] = nodeidx
			end
		end
	end

	local root = skin.joints[1];
	while (parents[root]) do
		root = parents[root]
	end

	return root;
end

local cache_tree = {}

local function redirect_skin_joints(scene)
	local skins = scene.skins
	if skins == nil then
		return
	end
	for _, skin in ipairs(scene.skins) do
		local joints = skin.joints
		local skeleton_nodeidx = find_skin_root_idx(scene, skin)

		if skeleton_nodeidx > 0 then
			local mapper = cache_tree[skeleton_nodeidx]
			if mapper == nil then
				mapper = {}
				local node_index = 0
				-- follow with ozz-animation:SkeleteBuilder, IterateJointsDF
				local function iterate_hierarchy_DF(nodes)
					for _, nidx in ipairs(nodes) do
						mapper[nidx] = node_index
						node_index = node_index + 1
						local node = scene.nodes[nidx+1]
						local c = node.children
						if c then
							iterate_hierarchy_DF(c)
						end
					end
				end
				iterate_hierarchy_DF{skeleton_nodeidx}

				cache_tree[skeleton_nodeidx] = mapper
			end

			for i=1, #joints do
				local joint_nodeidx = joints[i]
				joints[i] = assert(mapper[joint_nodeidx])
			end
		end
	end
end

local function export_meshbin(gltfscene, bindata)
	redirect_skin_joints(gltfscene)
	local scene_scalemat = gltfscene.scenescale and math3d.ref(math3d.matrix{s=gltfscene.scenescale}) or nil

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
						skin = fetch_inverse_bind_matrices(gltfscene, node.skin, bindata),
					}
	
					local meshaabb = math3d.aabb()
	
					for _, prim in ipairs(mesh.primitives) do
						local group = {
							mode = prim.mode,
							material = prim.material,
						}

						local attirbbuffers = fetch_attri_buffers(gltfscene, bindata, prim.attributes)

						group.vb = {
							values 	= attirbbuffers,
							start 	= 0,
							num 	= gltfutil.num_vertices(prim, gltfscene),
						}
	
						local indices_accidx = prim.indices
						if indices_accidx then
							local idxacc = gltfscene.accessors[indices_accidx+1]
							local bv = gltfscene.bufferViews[idxacc.bufferView+1]
							group.ib = {
								value 	= fetch_ib_info(bv, gen_indices_flags(idxacc), bindata, gltfscene.buffers),
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
	meshscene.scene = get_obj_name(gltfscene.scenes[def_sceneidx], def_sceneidx, "scene")
	return meshscene
end

return function (glbdata)
	return export_meshbin(glbdata.info, glbdata.bin)
end