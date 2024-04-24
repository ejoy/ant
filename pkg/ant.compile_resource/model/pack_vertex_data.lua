local mu = import_package "ant.math".util

local typemapper<const> = {
	f = 'f',
	i = 'H',
	u = 'B',
}
local jointidx_fmt<const> = "HHHH"
local color8bit_fmt<const> ="BBBB"

local function find_layout_idx(layouts, name)
	for i=1, #layouts do
		local l = layouts[i]
		if l.name == name then
			return i
		end
	end
end

local function unpack_vec(v, l)
	local t = l:sub(6, 6)
	t = typemapper[t] or error(("not support layout:%s, type:%s must be 'float'"):format(l, t))

	local n = tonumber(l:sub(2, 2))
	local fmt = t:rep(n)
	local vv = {fmt:unpack(v)}
	vv[n+1] = nil -- remove unpack offset
	return vv, fmt
end

local function load_attrib(attribidx, vertex, layout)
	return unpack_vec(vertex[attribidx], layout)
end
local function load_attrib_math3dvec(math3d, attribidx, vertex, layout)
	local r = load_attrib(attribidx, vertex, layout)
	if #r < 3 then
		r[3] = 0
	end
	return math3d.vector(r)
end

local PACK_TANGENT_FRAME<const> = true

return {
	pack = function (math3d, layouts, vertices)
		local weights_attrib_idx, joint_attrib_idx	= find_layout_idx(layouts, "WEIGHTS_0"), 	find_layout_idx(layouts, "JOINTS_0")
		local normal_attrib_idx, tangent_attrib_idx = find_layout_idx(layouts, "NORMAL"), 		find_layout_idx(layouts, "TANGENT")
		local color_attrib_idx 						= find_layout_idx(layouts, "COLOR_0")

		local function check_need_compress_color()
			if not color_attrib_idx then
				return false
			end
			return layouts[color_attrib_idx].layout:sub(6, 6) == 'i'
		end

		local need_compress_color<const>			= check_need_compress_color()
		local need_convert_joint_index<const> 		= joint_attrib_idx and layouts[joint_attrib_idx].layout:sub(6, 6) == 'u' or false

		local need_pack_tangent_frame<const>        = PACK_TANGENT_FRAME and normal_attrib_idx and tangent_attrib_idx

		local need_compress_tangent_frame<const>	= need_pack_tangent_frame
		local need_compress_weights<const>			= weights_attrib_idx
		local new_vertices = {}

		local function pack_tangent_frame(v)
			local normal = load_attrib_math3dvec(math3d, normal_attrib_idx, v, layouts[normal_attrib_idx].layout)
			local tangent = load_attrib_math3dvec(math3d, tangent_attrib_idx, v, layouts[tangent_attrib_idx].layout)

			local q = math3d.ext_util.pack_tangent_frame(normal, tangent)
			v[tangent_attrib_idx] = math3d.serialize(q)
		end

		local function compress_tangent_frame(v)
			local tv = load_attrib(tangent_attrib_idx, v, layouts[tangent_attrib_idx].layout)
			v[tangent_attrib_idx] = ('h'):rep(4):pack(mu.f2h(tv[1]), mu.f2h(tv[2]), mu.f2h(tv[3]), mu.f2h(tv[4]))
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
				cv[i] = mu.H2B(cv[i])
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
				v[weights_attrib_idx] = ('h'):rep(4):pack(mu.f2h(w[1]), mu.f2h(w[2]), mu.f2h(w[3]), mu.f2h(w[4]))
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

		local cp = math3d.checkpoint()
		for iv=1, #vertices do
			pack_vertex(vertices[iv])
		end
		math3d.recover(cp)

		local new_layouts = {}

		for _, l in ipairs(layouts) do
			--SKIP normal
			local canskip = need_pack_tangent_frame and l.name == "NORMAL"
			if not canskip then
				new_layouts[#new_layouts+1] = l.new_layout
			end
		end
		return new_vertices, table.concat(new_layouts, "|")
	end,
	is_pack2tangentframe = function (layouts)
		return PACK_TANGENT_FRAME and find_layout_idx(layouts, "NORMAL") and find_layout_idx(layouts, "TANGENT")
	end,
	find_attrib = function (layouts, attribname)
		return find_layout_idx(layouts, attribname)
	end,
}