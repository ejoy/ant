local gltfutil  = require "editor.model.glTF.util"
local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local assetmgr	= import_package "ant.asset"
local math3d    = require "math3d"
local utility   = require "editor.model.utility"

local function sort_pairs(t)
    local s = {}
    for k in pairs(t) do
        s[#s+1] = k
    end

    table.sort(s)

    local n = 1
    return function ()
        local k = s[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

local function get_layout(name, accessor)
	local shortname, channel = declmgr.parse_attri_name(name)
	local comptype_name = gltfutil.comptype_name_mapper[accessor.componentType]

	return 	shortname .. 
			tostring(gltfutil.type_count_mapper[accessor.type]) .. 
			tostring(channel) .. 
			(accessor.normalized and "n" or "N") .. 
			"I" .. 
			gltfutil.decl_comptype_mapper[comptype_name]
end

local function attrib_data(desc, iv, bin)
	local buf_offset = desc.bv_offset + iv * desc.stride + desc.acc_offset
	return bin:sub(buf_offset+1, buf_offset+desc.elemsize)
end

local function fetch_ib_buffer2(gltfscene, gltfbin, index_accessor)
	local bufferViews = gltfscene.bufferViews

	local bvidx = index_accessor.bufferView+1
	local bv = bufferViews[bvidx]
	local elemsize = gltfutil.accessor_elemsize(index_accessor)
	local class = {
		acc_offset = index_accessor.byteOffset or 0,
		bv_offset = bv.byteOffset or 0,
		elemsize = elemsize,
		stride = bv.byteStride or elemsize,
	}

	assert(elemsize == 2 or elemsize == 4)
	local offset = class.acc_offset + class.bv_offset
	local n = index_accessor.count
	local size = n * elemsize

	local indexbin = gltfbin:sub(offset+1, offset+size)
	local num_triangles = n // 3

	local buffer = {}
	local fmt = elemsize == 4 and "III" or "HHH"
	for tri=0, num_triangles-1 do
		local buffer_offset = tri * elemsize * 3
		local v0, v1, v2 = fmt:unpack(indexbin, buffer_offset+1)
		local s = fmt:pack(v0, v2, v1)
		buffer[#buffer+1] = s
	end

	indexbin = table.concat(buffer, "")

	return {
		memory = {indexbin, 1, #indexbin},
		flag = (elemsize == 4 and 'd' or ''),
		start 	= 0,
		num 	= index_accessor.count,
	}
end

local function fetch_ib_buffer(gltfscene, bindata, index_accessor)
	local bv = gltfscene.bufferViews[index_accessor.bufferView + 1]
	local elemsize = gltfutil.accessor_elemsize(index_accessor)

	local accoffset = index_accessor.byteOffset or 0
	local bvoffset = bv.byteOffset or 0
	local offset = accoffset + bvoffset + 1
	assert((bv.byteStride or elemsize) == elemsize)
	local value
	if elemsize == 1 then
		local buffers = {}
		local begidx = offset
		for i=1, index_accessor.count do
			local endidx = begidx+elemsize-1
			local v = bindata:sub(begidx, endidx)
			begidx = endidx + 1
			local idx = string.unpack("<B", v)
			buffers[#buffers+1] = string.pack("H", idx)
		end
		value = table.concat(buffers, "")
	elseif elemsize == 2 or elemsize == 4 then
		local numbytes = elemsize * index_accessor.count
		value = bindata:sub(offset, offset + numbytes -1)
	else
		error(("invalid index buffer elemenet size: %d"):format(elemsize))
	end
	return {
		memory = {value, 1, #value},
		flag = (elemsize == 4 and 'd' or ''),
		start 	= 0,
		num 	= index_accessor.count,
	}
end

local function create_prim_bounding(meshscene, prim)	
	local posacc = meshscene.accessors[assert(prim.attributes.POSITION)+1]
	local minv = posacc.min
	if minv then
		local maxv = posacc.max
		assert(#minv == 3)
		assert(#maxv == 3)

		--right hand to left hand
		maxv[3] = minv[3]
		minv[3] = maxv[3]
		local bounding = {
			aabb = {minv, maxv}
		}
		prim.bounding = bounding
		return bounding
	end
end

local function fetch_skininfo(gltfscene, skin, bindata)
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

local function get_obj_name(obj, idx, defname)
	if obj.name then
		return obj.name
	end

	return defname .. idx
end

local default_layouts<const> = {
	POSITION = 1,
	NORMAL = 1,
	TANGENT = 1,
	BITANGENT = 1,

	COLOR_0 = 3,
	COLOR_1 = 3,
	COLOR_2 = 3,
	COLOR_3 = 3,
	TEXCOORD_0 = 3,
	TEXCOORD_1 = 3,
	TEXCOORD_2 = 3,
	TEXCOORD_3 = 3,
	TEXCOORD_4 = 3,
	TEXCOORD_5 = 3,
	TEXCOORD_6 = 3,
	TEXCOORD_7 = 3,
	JOINTS_0 = 2,
	WEIGHTS_0 = 2,
}

local LAYOUT_NAMES<const> = {
	"POSITION",
	"NORMAL",
	"TANGENT",
	"BITANGENT",
	"COLOR_0",
	"COLOR_1",
	"COLOR_2",
	"COLOR_3",
	"TEXCOORD_0",
	"TEXCOORD_1",
	"TEXCOORD_2",
	"TEXCOORD_3",
	"TEXCOORD_4",
	"TEXCOORD_5",
	"TEXCOORD_6",
	"TEXCOORD_7",
	"JOINTS_0",
	"WEIGHTS_0",
}

local jointidx_fmt<const> = "HHHH"

-- change from right hand to left hand
-- left hand define as: 
-- 		x: -left, +right
-- 		y: +up, -down
--		z: +point2user, -point2screen
-- right hand define as:
-- 		x: -left, +right
-- 		y: +up, -down
--		z: -point2user, +point2screen
local function r2l_vec(v, l)
	local t = l:sub(6, 6)
	if t == 'f' then
		local x, y, z = ('fff'):unpack(v)
		z = -z
		return ('fff'):pack(x, y, z)
	end

	assert(("not support layout:%s, %s"):format(l, t))
end

local function fetch_vb_buffers2(gltfscene, gltfbin, prim)
	assert(prim.mode == nil or prim.mode == 4)
	local attributes = prim.attributes
	local accessors, bufferViews, buffers = gltfscene.accessors, gltfscene.bufferViews, gltfscene.buffers
	local layoutdesc = {}
	local layouts = {}

	for _, attribname in ipairs(LAYOUT_NAMES) do
		local accidx = attributes[attribname]
		if accidx then
			local acc = accessors[accidx+1]
			local bvidx = acc.bufferView+1
			local bv = bufferViews[bvidx]
			layouts[#layouts+1] = get_layout(attribname, accessors[accidx+1])
			local elemsize = gltfutil.accessor_elemsize(acc)
			layoutdesc[#layoutdesc+1] = {
				acc_offset = acc.byteOffset or 0,
			 	bv_offset = bv.byteOffset or 0,
				elemsize = elemsize,
			 	stride = bv.byteStride or elemsize,
			}
		end
	end

	local buffer = {}
	local numv = gltfutil.num_vertices(prim, gltfscene)

	local change_index_attrib = -1
	for iv=0, numv-1 do
		for idx, d in ipairs(layoutdesc) do
			local l = layouts[idx]
			local v = attrib_data(d, iv, gltfbin)

			local t = l:sub(1, 1)
			if t == 'p' or t == 'n' or t == 'T' or t == 'b' then
				v = r2l_vec(v, l)
			elseif t == 'i' then
				if l:sub(6, 6) == 'u' then
					v = jointidx_fmt:pack(v:byte(1), v:byte(2), v:byte(3), v:byte(4))
					change_index_attrib = idx
				end
			end
			buffer[#buffer+1] = v
		end
	end

	if change_index_attrib ~= -1 then
		layouts[change_index_attrib] = layouts[change_index_attrib]:sub(1, 5) .. 'i'
	end

	local bindata = table.concat(buffer, "")
	return {
		{
			declname = table.concat(layouts, '|'),
			memory = {bindata, 1, #bindata},
		},
		start = 0,
		num = numv,
	}
end

local function fetch_vb_buffers(gltfscene, gltfbin, prim)
	local attributes = prim.attributes
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
	local bufferidx = 1
	local function vertex_attrib(class, iv)
		local acc_offset, bv_offset, elemsize, stride = class[1], class[2], class[3], class[4]
		local elemoffset = bv_offset + iv * stride + acc_offset + 1
		return gltfbin:sub(elemoffset, elemoffset + elemsize - 1)
	end

	local function joint_vertex_attrib(class, iv)
		local joint_va = vertex_attrib(class, iv)
		assert(#joint_va == 4)
		return jointidx_fmt:pack(joint_va:byte(1), joint_va:byte(2), joint_va:byte(3), joint_va:byte(4))
	end

	local function get_vertex_attrib_op(declname)
		if declname:sub(1, 1) == "i" and declname:sub(6, 6) == "u" then
			assert(declname:sub(2, 2) == '4')
			return joint_vertex_attrib, declname:sub(1, 5) .. "i"
		end
		return vertex_attrib, declname
	end

	for _, attribclass in sort_pairs(attribclasses) do
		local declname = {}
		local cacheclass = {}
		for _, info in ipairs(attribclass) do
			local attribname, accidx = info[1], info[2]
			local acc = accessors[accidx+1]
			local bv = bufferviews[acc.bufferView+1]

			local acc_offset = acc.byteOffset or 0
			local bv_offset = bv.byteOffset or 0

			local elemsize = gltfutil.accessor_elemsize(acc)
			local d = get_layout(attribname, acc)
			local va
			va, d = get_vertex_attrib_op(d)
			declname[#declname+1] = d
			cacheclass[#cacheclass+1] = {acc_offset, bv_offset, elemsize, bv.byteStride or elemsize, vertex_attrib = va}
		end

		local buffer = {}
		for ii=0, numv-1 do
			for jj=1, #cacheclass do
				local c = cacheclass[jj]
				buffer[#buffer+1] = c:vertex_attrib(ii)

				-- local buf = gltfbin:sub(elemoffset, elemoffset + elemsize - 1)
				-- local size = elemsize / 4
				-- local formats = {[1] = "f", [2] = "ff", [3] = "fff", [4] = "ffff"}

				-- local t = table.pack(string.unpack(formats[size], buf))
				-- print(table.concat(t, " "))
				-- buffer[#buffer+1] = buf
			end
		end

		local bindata = table.concat(buffer, "")
		attribuffers[bufferidx] = {
			declname = table.concat(declname, "|"),
			memory = {bindata, 1, #bindata},
		}
		bufferidx = bufferidx+1
	end

	attribuffers.start 	= 0
	attribuffers.num 	= gltfutil.num_vertices(prim, gltfscene)
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

local function redirect_skin_joints(gltfscene, skin)
	local joints = skin.joints
	local skeleton_nodeidx = find_skin_root_idx(gltfscene, skin)

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
					local node = gltfscene.nodes[nidx+1]
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

local function export_skinbin(gltfscene, bindata, exports)
	exports.skin = {}
	local skins = gltfscene.skins
	if skins == nil then
		return
	end
	for skinidx, skin in ipairs(gltfscene.skins) do
		redirect_skin_joints(gltfscene, skin)
		local skinname = get_obj_name(skin, skinidx, "skin")
		local resname = "./meshes/"..skinname .. ".skinbin"
		utility.save_bin_file(resname, fetch_skininfo(gltfscene, skin, bindata))
		exports.skin[skinidx] = resname
	end
end

local function export_meshbin(gltfscene, bindata, exports)
	exports.mesh = {}
	local meshes = gltfscene.meshes
	if meshes == nil then
		return
	end
	for meshidx, mesh in ipairs(meshes) do
		local meshname = get_obj_name(mesh, meshidx, "mesh")
		local meshaabb = math3d.aabb()
		exports.mesh[meshidx] = {}
		for primidx, prim in ipairs(mesh.primitives) do
			local group = {}
			group.vb = fetch_vb_buffers2(gltfscene, bindata, prim)
			local indices_accidx = prim.indices
			if indices_accidx then
				local idxacc = gltfscene.accessors[indices_accidx+1]
				group.ib = fetch_ib_buffer2(gltfscene, bindata, idxacc)
			end
			local bb = create_prim_bounding(gltfscene, prim)
			if bb then
				group.bounding = bb
				meshaabb = math3d.aabb_merge(meshaabb, math3d.aabb(bb.aabb[1], bb.aabb[2]))
			end
			local primname = "P" .. primidx
			local resname = "./meshes/"..meshname .. "_" .. primname .. ".meshbin"
			utility.save_bin_file(resname, group)
			exports.mesh[meshidx][primidx] = resname
		end
	end
end

return function (_, glbdata, exports)
	export_meshbin(glbdata.info, glbdata.bin, exports)
	export_skinbin(glbdata.info, glbdata.bin, exports)
	return exports
end
