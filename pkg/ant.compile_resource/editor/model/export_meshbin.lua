local gltfutil  = require "editor.model.glTF.util"
local math3d    = require "math3d"
local utility   = require "editor.model.utility"
local mathpkg	= import_package "ant.math"
local mc, mu	= mathpkg.constant, mathpkg.util
local cs_skinning = true
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

-- ant.render/vertexdecl_mgr.lua has defined this mapper, but we won't want to dependent ant.render in this package
local SHORT_NAMES<const> = {
	POSITION = 'p', NORMAL = 'n', COLOR = 'c',
	TANGENT = 'T', BITANGENT = 't',	TEXCOORD = 't',
	JOINTS = 'i', WEIGHTS = 'w'	-- that is special defines
}

local function get_layout(name, accessor)
	local attribname, channel = name:match"(%w+)_(%d+)"
	local shortname = SHORT_NAMES[attribname or name]
	local comptype_name = gltfutil.comptype_name_mapper[accessor.componentType]
	local shorttype = gltfutil.decl_comptype_mapper[comptype_name]
	local asInt = shorttype ~= 'f' and 'i' or 'I'
	return ("%s%d%d%s%s%s"):format(
		shortname,
		gltfutil.type_count_mapper[accessor.type],
		channel or 0,
		(accessor.normalized and "n" or "N"),
		asInt,
		shorttype)
end

local function attrib_data(desc, iv, bin)
	local buf_offset = desc.bv + iv * desc.stride + desc.acc
	return bin:sub(buf_offset+1, buf_offset+desc.size)
end

local function to_ib(indexbin, flag, count)
	return {
		memory 	= {indexbin, 1, #indexbin},
		flag 	= flag,
		start 	= 0,
		num 	= count,
	}
end

 local function fetch_ib_buffer(gltfscene, gltfbin, index_accessor, ib_table)
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
		ib_table[#ib_table + 1] = v0
		ib_table[#ib_table + 1] = v2
		ib_table[#ib_table + 1] = v1
		buffer[#buffer+1] = fmt:pack(v0, v2, v1)
	end

	indexbin = table.concat(buffer, "")

	return to_ib(indexbin, elemsize == 4 and 'd' or '', index_accessor.count)
end 

local function create_prim_bounding(meshscene, prim)	
	local posacc = meshscene.accessors[assert(prim.attributes.POSITION)+1]
	local minv = posacc.min
	if minv then
		local maxv = posacc.max
		assert(#minv == 3)
		assert(#maxv == 3)

		local nminv, nmaxv = math3d.minmax{
			{minv[1], minv[2], -minv[3]},
			{maxv[1], maxv[2], -maxv[3]},
		}
		local bounding = {
			aabb = {math3d.tovalue(nminv), math3d.tovalue(nmaxv)}
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

local jointidx_fmt<const> = "HHHH"
local color8bit_fmt<const> ="BBBB"

local typemapper<const> = {
	f = 'f',
	i = 'H',
	u = 'B',
}

local function unpack_vec(v, l)
	local t = l:sub(6, 6)
	t = typemapper[t]
	if t == nil then
		assert(("not support layout:%s, type:%s must be 'float'"):format(l, t))
	end

	local n = tonumber(l:sub(2, 2))
	local fmt = t:rep(n)
	local vv = {fmt:unpack(v)}
	vv[n+1] = nil -- remove unpack offset
	return vv, fmt
end

-- change from right hand to left hand
-- left hand define as: 
-- 		x: -left, +right
-- 		y: +up, -down
--		z: -point2user, +point2screen
-- right hand define as:
-- 		x: -left, +right
-- 		y: +up, -down
--		z: +point2user, -point2screen
local function r2l_vec_v(v, l)
	local vv, fmt = unpack_vec(v, l)
	if vv[3] and l:sub(6,6) == 'f' then
		vv[3] = -vv[3]
	end
	return vv, fmt
end


local function r2l_vec(v, l)
	local vv, fmt = r2l_vec_v(v, l)
	return fmt:pack(table.unpack(vv))
end

local function find_layout(layouts, name)
	for i=1, #layouts do
		local l = layouts[i]
		if l.name == name then
			return l
		end
	end
end

local function find_layout_idx(layouts, name)
	for i=1, #layouts do
		local l = layouts[i]
		if l.name == name then
			return i
		end
	end
end

local function calc_tangents(ib, vb, layouts)
	local tangents, bitangents = {}, {}

	local pos_attrib_idx, tex_attrib_idx = find_layout_idx(layouts, "POSITION"), find_layout_idx(layouts, "TEXCOORD_0")
	local pos_layout, tex_layout = layouts[pos_attrib_idx].layout, layouts[tex_attrib_idx].layout
	local function store(iv, v)
		local x, y, z, w = math3d.index(v, 1, 2, 3, 4)
		local vv = vb[iv]
		vv[#vv+1] = ('ffff'):pack(x, y, z, w)
	end

	local function load_vec(v, idx, layout)
		local p = unpack_vec(v[idx], layout)
		return math3d.vector(p)
	end

	local function load_vertex(vidx)
		local v = vb[vidx]
		local t = unpack_vec(v[tex_attrib_idx], tex_layout)
		return {
			p = load_vec(v, pos_attrib_idx, pos_layout),
			u = t[1], v = t[2]
		}
	end

	--[[
		tangent calculation:
		we have 3 vertices: a, b, c, which have position and uv defined in triangle abc, we make:
			tangent T and bitangent B:
				b.p - a.p = (b.u-a.u)*T + (b.v-a.v)*B
				c.p - a.p = (c.u-a.u)*T + (c.v-a.v)*B
			make:
				ba=b.p-a.p, bau=b.u-a.u, bav=b.v-a.v
				ca=c.p-a.p, cau=c.u-a.u, cav=c.v-a.v

				ba = bau*T + bav*B	==> ba.x = bau*T.x + bav*B.x | ba.y = bau*T.y + bav*B.y | ba.z = bau*T.z + bav*B.z
				ca = cau*T + cav*B	==> ca.x = cau*T.x + cav*B.x | ca.y = cau*T.y + cav*B.y | ca.z = cau*T.z + cav*B.z

				cav*ba = cav*bau*T + cav*bav*B
				bav*ca = bav*cau*T + bav*cav*B

				bav*ca - cav*ba = (bav*cau-cav*bau)*T	==> T = (bav*ca - cav*ba)/(bav*cau - cav*bau)

				let det = (bav*cau-cav*bau), invdet = 1/(bav*cau-cav*bau)
				T = (bav*ca - cav*ba) * invdet

			we can solve T and B
	]]

	local function calc_tangent(vidx0, vidx1, vidx2)
		local a, b, c = load_vertex(vidx0), load_vertex(vidx1), load_vertex(vidx2)

		local ba = math3d.sub(b.p, a.p)
		local ca = math3d.sub(c.p, a.p)
		local bau, bav = b.u - a.u, b.v - a.v
		local cau, cav = c.u - a.u, c.v - a.v

		local det<const> = bau * cav - bav * cau
		local t, bi
		if mu.iszero(det) then
			t, bi = mc.XAXIS, mc.ZAXIS
		else
			local invDet<const> = 1.0 / det

			--(ba * cav - ca * bav) * invDet
			--(ca * bau - ba * cau) * invDet
			t, bi = math3d.mul(math3d.sub(math3d.mul(ba, cav), math3d.mul(ca, bav)), invDet),
					math3d.mul(math3d.sub(math3d.mul(ca, bau), math3d.mul(ba, cau)), invDet)
		end

		-- we will merge tangent and bitangent value
		tangents[vidx0]		= tangents[vidx0] and math3d.add(tangents[vidx0], t) or t
		tangents[vidx1]		= tangents[vidx1] and math3d.add(tangents[vidx1], t) or t
		tangents[vidx2]		= tangents[vidx2] and math3d.add(tangents[vidx2], t) or t

		bitangents[vidx0]	= bitangents[vidx0] and math3d.add(bitangents[vidx0], bi) or bi
		bitangents[vidx1]	= bitangents[vidx1] and math3d.add(bitangents[vidx1], bi) or bi
		bitangents[vidx2]	= bitangents[vidx2] and math3d.add(bitangents[vidx2], bi) or bi
	end

	if ib then
		for i=1, #ib, 3 do
			local vidx0, vidx1, vidx2 = ib[i]+1, ib[i+1]+1, ib[i+2]+1
			calc_tangent(vidx0, vidx1, vidx2)
		end
	else
		for iv=1, #vb, 3 do
			calc_tangent(iv, iv+1, iv+2)
		end
	end

	local normal_attrib_idx = find_layout_idx(layouts, "NORMAL")
	local normal_layout = layouts[normal_attrib_idx].layout

	-- see: http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping/#tangent-and-bitangent
	local function make_vector_perpendicular(srcvec, basevec)
		local ndt	= math3d.dot(srcvec, basevec)
		return math3d.sub(srcvec, math3d.mul(basevec, ndt))
	end

	for iv=1, #vb do
		local tanu 		= tangents[iv]
		local tanv 		= bitangents[iv]
		local normal 	= load_vec(vb[iv], normal_attrib_idx, normal_layout)

		local tangent	= make_vector_perpendicular(tanu, normal)
		local bitangent	= make_vector_perpendicular(tanv, normal)

		if mu.iszero_math3dvec(tangent) or mu.isnan_math3dvec(tangent) then
			if mu.iszero_math3dvec(bitangent) or mu.isnan_math3dvec(bitangent) then
				tangent = mc.XAXIS
			else
				tangent = math3d.cross(bitangent, normal)
			end
		end

		tangent	= math3d.normalize(tangent)

		local nxt    	= math3d.cross(normal, tangent)
		tangent	= math3d.set_index(tangent, 4, math3d.dot(nxt, bitangent) < 0 and -1.0 or 1.0)
		store(iv, tangent)
	end
end

local function r2l_buf(d, iv, gltfbin)
	local v = attrib_data(d, iv, gltfbin)
	return r2l_vec(v, d.layout)
end

local function is_vec_attrib(an)
	return ("pnTbc"):match(an)
end

local function need_calc_tangent(layouts)
	return find_layout(layouts, "TANGENT") == nil and find_layout(layouts, "NORMAL") and find_layout(layouts, "TEXCOORD_0")
end

local function generate_layouts(gltfscene, attributes)
	local accessors, bufferViews = gltfscene.accessors, gltfscene.bufferViews

	local layouts = {}
	for _, attribname in ipairs(LAYOUT_NAMES) do
		local accidx = attributes[attribname]
		if accidx then
			local acc = accessors[accidx+1]
			local bvidx = acc.bufferView+1
			local bv = bufferViews[bvidx]
			local elemsize = gltfutil.accessor_elemsize(acc)
			local layout = get_layout(attribname, accessors[accidx+1])
			local layouttype = layout:sub(1, 1)
			local l = {
				name	= attribname,
				layout 	= layout,
				acc		= acc.byteOffset or 0,
			 	bv		= bv.byteOffset or 0,
				size	= elemsize,
			 	stride	= bv.byteStride or elemsize,
				fetch_buf = is_vec_attrib(layouttype) and r2l_buf or attrib_data,
			}
			layouts[#layouts+1] = l
		end
	end
	return layouts
end

local function fetch_vertices(layouts, gltfbin, numv, reverse_wing_order)
	local vertices = {}
	for iv=0, numv-1 do
		local v = {}
		for _, l in ipairs(layouts) do
			v[#v+1] = l:fetch_buf(iv, gltfbin)
		end
		vertices[#vertices+1] = v
	end

	if reverse_wing_order then
		assert((numv // 3)*3 == numv)
		for iv=1, numv, 3 do
			-- swap v3 and v2
			vertices[iv+1], vertices[iv+2] = vertices[iv+2], vertices[iv+1]
		end
	end
	return vertices
end

local function pack_cs_skinning_layout(layouts)
	local ll = {}
	for _, l in ipairs(layouts) do
		local t = l.layout:sub(1, 1)
		local idx = l.layout:sub(3, 3)
		ll[#ll+1] = ("%s4%sNIf"):format(t, idx)
	end
	return table.concat(ll, "|")
end


local function pack_layout(layouts, need_pack_tangent_frame, need_convert_joint_index, need_compress_color, need_convert_weight_index)
	local ll = {}
	for _, l in ipairs(layouts) do
		if need_pack_tangent_frame and l.name == "TANGENT" then
			ll[#ll+1] = "T40nii"
			goto continue
		end
 		if need_convert_joint_index and l.name == "JOINTS_0" then
			ll[#ll+1] = l.layout:sub(1, 5) .. 'i'
			goto continue
		end
		if need_convert_weight_index and l.name:match "WEIGHTS_0" then
			ll[#ll+1] = "w40nii"
			goto continue
		end 
		if need_compress_color and l.name:match "COLOR_" then
			ll[#ll+1] = l.layout:sub(1, 5) .. 'u'
			goto continue
		end
		-- skip NORMAL when pack tangent frame
		if need_pack_tangent_frame and l.name == "NORMAL" then
			goto continue
		end
		ll[#ll+1] = l.layout
		::continue::
	end
	return table.concat(ll, '|')
end

local fmt_f<const> = ('f'):rep(4)

local function u16tou8(vv)
	return math.floor(vv/65535.0*255+0.5)
end
local function u16tof(vv)
	return vv/65535.0
end
local function u8tof(vv)
	return vv/255.0
end

local function load_attrib(attribidx, vertex, layout)
	return unpack_vec(vertex[attribidx], layout)
end
local function load_attrib_math3dvec(attribidx, vertex, layout)
	local r = load_attrib(attribidx, vertex, layout)
	if #r < 3 then
		r[3] = 0
	end
	return math3d.vector(r)
end

local function pack_vertex_data(layouts, vertices)
	local function check_nan(v)
		if v ~= v then
			return 0
		else
			return v
		end
	end
	local function f2i(v)
		return math.floor(check_nan(v) * 32767)
	end

	local weights_attrib_idx, joint_attrib_idx	= find_layout_idx(layouts, "WEIGHTS_0"), 	find_layout_idx(layouts, "JOINTS_0")
	local normal_attrib_idx, tangent_attrib_idx = find_layout_idx(layouts, "NORMAL"), 		find_layout_idx(layouts, "TANGENT")
	local color_attrib_idx 						= find_layout_idx(layouts, "COLOR_0")

	local need_vec4_format                      = weights_attrib_idx and joint_attrib_idx and cs_skinning

	local function check_need_compress_color(color_attrib_idx)
		if not color_attrib_idx then
			return false
		end

		if need_vec4_format then
			return false
		end

		--TODO: only convert color with 16 bits, we need to compress float to uint8
		return layouts[color_attrib_idx].layout:sub(6, 6) == 'i'
	end

	local need_compress_color<const>			= check_need_compress_color()
	local need_convert_joint_index<const> 		= joint_attrib_idx and layouts[joint_attrib_idx].layout:sub(6, 6) == 'u' or false

	local need_pack_tangent_frame<const>        = normal_attrib_idx and tangent_attrib_idx

	local need_compress_tangent_frame<const>	= need_pack_tangent_frame and (not need_vec4_format)
	local need_compress_weights<const>			= weights_attrib_idx and (not need_vec4_format)
	local new_vertices = {}

	local function pack_tangent_frame(v)
		local normal = load_attrib_math3dvec(normal_attrib_idx, v, layouts[normal_attrib_idx].layout)
		local tangent = load_attrib_math3dvec(tangent_attrib_idx, v, layouts[normal_attrib_idx].layout)
		
		local q = mu.pack_tangent_frame(normal, tangent)
		local qx, qy, qz, qw = math3d.index(q, 1, 2, 3, 4)

		v[tangent_attrib_idx] = ('f'):rep(4):pack(qx, qy, qz, qw)
	end

	local function compress_tangent_frame(v)
		local tv = load_attrib(tangent_attrib_idx, v, layouts[tangent_attrib_idx].layout)
		v[tangent_attrib_idx] = ('h'):rep(4):pack(f2i(tv[1]), f2i(tv[2]), f2i(tv[3]), f2i(tv[4]))
	end

	local function build_new_layout()
		for _, l in ipairs(layouts) do
			if l.name == "TANGENT" then
				if need_pack_tangent_frame and need_compress_tangent_frame then
					l.new_layout = "T40nii"
					goto continue
				end
			elseif l.name:match "JOINTS" then
				if need_convert_joint_index then
					l.new_layout = l.layout:sub(1, 5) .. 'i'
					goto continue
				end
			elseif l.name:match "WEIGHTS" then
				if need_compress_weights then
					l.new_layout = "w40nii"
					goto continue
				end
			elseif l.name:match "COLOR" then
				if need_compress_color then
					l.new_layout = l.layout:sub(1, 5) .. 'u'
					goto continue
				end
			end

			l.new_layout = l.layout
			::continue::
		end
	end

	build_new_layout()

	local function compress_color(v)
		local cv = load_attrib(color_attrib_idx, v, layouts[color_attrib_idx].layout)
		for i=1, 4 do
			cv[i] = u16tou8(cv[i])
		end
		v[color_attrib_idx] = color8bit_fmt:pack(cv[1], cv[2], cv[3], cv[4])
	end

	local function make_joint_index_as_int16(v)
		local j = v[joint_attrib_idx]
		v[joint_attrib_idx] = jointidx_fmt:pack(j:byte(1), j:byte(2), j:byte(3), j:byte(4))
	end

	local function convert_vertex(v)
		if need_pack_tangent_frame then
			pack_tangent_frame(v)
			if need_compress_tangent_frame then
				compress_tangent_frame(v)
			end
		end

		if need_compress_color then
			compress_color(v)
		end

		if need_convert_joint_index then
			make_joint_index_as_int16(v)
		end

		if need_compress_weights then
			local w = load_attrib(weights_attrib_idx, v, layouts[weights_attrib_idx].layout)
			v[weights_attrib_idx] = ('h'):rep(4):pack(f2i(w[1]), f2i(w[2]), f2i(w[3]), f2i(w[4]))
		end
	end

	local function pack_vertex(v)
		convert_vertex(v)

		if need_pack_tangent_frame then
			-- remove normal
			table.remove(v, normal_attrib_idx)
		end
		new_vertices[#new_vertices+1] = table.concat(v, "")
	end

	local function pack_vertex_as_vec4(v)
		convert_vertex(v)

		local nv = {}

		local function attrib2vec4(ai, layout)
			local av = load_attrib(ai, v, layout)
			local elemtype = layout:sub(6, 6)
			local cvt
			if elemtype == 'i' then
				cvt = u16tof
			elseif elemtype == 'u' then
				cvt = u8tof
			else
				if elemtype ~= 'f' then
					error(("Invalid element format type:%s, only support [iuf]/[int16/uint8/float]"):format(elemtype))
				end
			end
		
			if cvt then
				for i=1, #av do
					av[i] = u16tof(av[i])
				end
			end
		
			assert(#av <= 4, "Not support attrib element more than 4")
			for i=#av+1, 4 do
				av[i] = 0	--padding
			end
			return fmt_f:pack(table.unpack(av))
		end

		for ai, l in ipairs(layouts) do
			local canskip = need_pack_tangent_frame and l.name == "NORMAL"
			if not canskip then
				nv[#nv+1] = attrib2vec4(ai, l.new_layout)
			end
		end
		new_vertices[#new_vertices+1] = table.concat(nv,"")
	end

	local pv_func = need_vec4_format and pack_vertex_as_vec4 or pack_vertex

	for iv=1, #vertices do
		pv_func(vertices[iv])
	end

	local new_layouts = {}
	if need_vec4_format then
		for _, l in ipairs(layouts) do
			local t = l.new_layout:sub(1, 1)
			local idx = l.new_layout:sub(3, 3)
			local canskip = need_pack_tangent_frame and l.name == "NORMAL"
			if not canskip then
				new_layouts[#new_layouts+1] = ("%s4%sNIf"):format(t, idx)
			end
		end
	else
		for _, l in ipairs(layouts) do
			--SKIP normal
			local canskip = need_pack_tangent_frame and l.name == "NORMAL"
			if not canskip then
				new_layouts[#new_layouts+1] = l.new_layout
			end
		end
	end

	return new_vertices, table.concat(new_layouts, "|")
end

local function fetch_vb_buffers(gltfscene, gltfbin, prim, ib_table, settings)
	assert(prim.mode == nil or prim.mode == 4)

	local layouts = generate_layouts(gltfscene, prim.attributes)

	local numv = gltfutil.num_vertices(prim, gltfscene)
	local vertices = fetch_vertices(layouts, gltfbin, numv, ib_table == nil)

	if need_calc_tangent(layouts) then
		math3d.reset()
		calc_tangents(ib_table, vertices, layouts)
		math3d.reset()
		layouts[#layouts+1] = {
			layout		= "T40NIf",
			fetch_buf	= attrib_data,	-- this tangent already in left hand space
			name		= "TANGENT",
		}
	end

	local new_vertices, new_layout = pack_vertex_data(layouts, vertices)
	local bindata = table.concat(new_vertices, "")

	return {
		declname = new_layout,
		memory = {bindata, 1, #bindata},
		start = 0,
		num = numv,
	}
end

local function find_skin_root_idx(skin, nodetree)
	local joints = skin.joints
	if joints == nil or #joints == 0 then
		return
	end

	if skin.skeleton then
		return skin.skeleton
	end

	local root = joints[1]
	while true do
		local p = nodetree[root]
		if p == nil then
			break
		end

		root = p
	end
	return root
end

local joint_trees = {}

local function redirect_skin_joints(gltfscene, skin, joint_index, scenetree)
	local skeleton_nodeidx = find_skin_root_idx(skin, scenetree)

	if skeleton_nodeidx then
		local mapper = joint_trees[skeleton_nodeidx]
		if mapper == nil then
			mapper = {}
			-- follow with ozz-animation:SkeletonBuilder, IterateJointsDF
			local function iterate_hierarchy_DF(nodes)
				for _, nidx in ipairs(nodes) do
					mapper[nidx] = joint_index
					joint_index = joint_index + 1
					local node = gltfscene.nodes[nidx+1]
					local c = node.children
					if c then
						iterate_hierarchy_DF(c)
					end
				end
			end
			iterate_hierarchy_DF{skeleton_nodeidx}

			joint_trees[skeleton_nodeidx] = mapper
		end

		local joints = skin.joints
		for i=1, #joints do
			local joint_nodeidx = joints[i]
			joints[i] = assert(mapper[joint_nodeidx])
		end
	end

	return joint_index
end

local function export_skinbin(gltfscene, bindata, exports)
	exports.skin = {}
	local skins = gltfscene.skins
	if skins == nil then
		return
	end
	local joint_index = 0
	for skinidx, skin in ipairs(gltfscene.skins) do
		joint_index = redirect_skin_joints(gltfscene, skin, joint_index, exports.scenetree)
		local skinname = get_obj_name(skin, skinidx, "skin")
		local resname = "./meshes/"..skinname .. ".skinbin"
		utility.save_bin_file(resname, fetch_skininfo(gltfscene, skin, bindata))
		exports.skin[skinidx] = resname
	end

	local nodejoints = {}
	for root_nodeidx, t in pairs(joint_trees) do
		assert(t[root_nodeidx])
		for nodeidx, jointidx in pairs(t) do
			nodejoints[nodeidx] = jointidx
		end
	end
	exports.node_joints = nodejoints
end

-- local function check_front_face(vb, ib)
-- 	local function read_memory(m, fmt, offset)
-- 		offset = offset or 1
-- 		local d, o = m[1], m[2]
-- 		return fmt:unpack(d, offset)
-- 	end

	
-- 	local i1, i2, i3
-- 	if ib then
-- 		local fmt = ib.flag == '' and "HHH" or "III"
-- 		i1, i2, i3 = read_memory(ib.memory, fmt)
-- 	else
-- 		i1, i2, i3 = 1, 2, 3
-- 	end

-- 	assert(#vb == 1 and vb[1].declname:match "p")
-- 	local b = vb[1]
	

-- 	local stride_offset = 0
-- 	local fmt
-- 	do
-- 		for d in b.declname:gmatch "[^|]" do
-- 			if d:sub(1, 1) == 'p' then
-- 				local t = d:sub(6, 6)
-- 				local m<const> = {
-- 					['f'] = 'f',
-- 					['u'] = 'B',
-- 					['i'] = 'h',
-- 				}
-- 				local n = math.floor(tonumber(d:sub(2, 2)))
-- 				fmt = m[t]:rep(n)
-- 				break
-- 			end

-- 			stride_offset = stride_offset + declmgr.elem_size(d)
-- 		end
-- 	end

-- 	local stride = declmgr.layout_stride(b.declname)
-- 	if fmt == nil then
-- 		error "invalid vertex buffer"
-- 	end

-- 	local function vertex_offset(idx)
-- 		return idx * stride + stride_offset
-- 	end
-- 	local v1 = {read_memory(b.memory, fmt, vertex_offset(i1))}
-- 	local v2 = {read_memory(b.memory, fmt, vertex_offset(i2))}
-- 	local v3 = {read_memory(b.memory, fmt, vertex_offset(i3))}

-- 	--left hand check
-- 	v1[3] = 0.0
-- 	v2[3] = 0.0
-- 	v3[3] = 0.0
-- 	local e1 = math3d.sub(v2, v1)
-- 	local e2 = math3d.sub(v3, v1)
-- 	math3d.cross(e1, e2)

-- end

local function save_meshbin_files(resname, meshgroup)
	local cfgname = ("./meshes/%s.meshbin"):format(resname)

	local function write_bin_file(fn, bin)
		utility.save_file("./meshes/" .. fn, bin)
		return fn
	end

	local vb = assert(meshgroup.vb)
	vb.memory[1] = write_bin_file(resname .. ".vbbin", vb.memory[1])
	local ib = meshgroup.ib
	if ib then
		ib.memory[1] = write_bin_file(resname .. ".ibbin", ib.memory[1])
	end

	utility.save_txt_file(cfgname, meshgroup)
	return cfgname
end


 local function export_meshbin(gltfscene, bindata, exports)
	exports.mesh = {}
	local meshes = gltfscene.meshes
	if meshes == nil then
		return
	end
	for meshidx, mesh in ipairs(meshes) do
		local meshname = get_obj_name(mesh, meshidx, "mesh")
		--local meshaabb = math3d.aabb()
		exports.mesh[meshidx] = {}
		for primidx, prim in ipairs(mesh.primitives) do
			local ib_table = {}
			local group = {}
			local indices_accidx = prim.indices

			--TODO: if no index buffer, just switch vb order, not create a new index buffer
			if indices_accidx then
				group.ib = fetch_ib_buffer(gltfscene, bindata, gltfscene.accessors[indices_accidx+1], ib_table)
			end

			group.vb = fetch_vb_buffers(gltfscene, bindata, prim, ib_table)
			local bb = create_prim_bounding(gltfscene, prim)
			if bb then
				local aabb = math3d.aabb(bb.aabb[1], bb.aabb[2])
				if math3d.aabb_isvalid(aabb) then
					group.bounding = bb
					--meshaabb = math3d.aabb_merge(meshaabb, aabb)
				end
			end

			local stemname = ("%s_P%d"):format(meshname, primidx)
			exports.mesh[meshidx][primidx] = {
				meshbinfile = save_meshbin_files(stemname, group),
				declname = group.vb.declname,
			}
		end
	end

	--calculate tangent info will use too many math3d resource, we need to reset here
	math3d.reset()
end 

--[[ local function export_meshbin(gltfscene, bindata, exports)
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
			group.vb = fetch_vb_buffers(gltfscene, bindata, prim)
			local indices_accidx = prim.indices
			group.ib = indices_accidx and
				fetch_ib_buffer(gltfscene, bindata, gltfscene.accessors[indices_accidx+1]) or
				gen_ib(group.vb.num)

			local bb = create_prim_bounding(gltfscene, prim)
			if bb then
				local aabb = math3d.aabb(bb.aabb[1], bb.aabb[2])
				if math3d.aabb_isvalid(aabb) then
					group.bounding = bb
					meshaabb = math3d.aabb_merge(meshaabb, aabb)
				end
			end

			local stemname = ("%s_P%d"):format(meshname, primidx)
			exports.mesh[meshidx][primidx] = save_meshbin_files(stemname, group)
		end
	end
end ]]

return function (_, glbdata, exports, settings)
	joint_trees = {}
	export_meshbin(glbdata.info, glbdata.bin, exports, settings)
	export_skinbin(glbdata.info, glbdata.bin, exports)
	return exports
end