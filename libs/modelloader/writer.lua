local function string_pack(v)
	return v
end

local function uint_pack(v)
	return string.pack("I4", v)
end

local function uint8_pack(v)
	return string.pack("I1", v)
end

local function boolean_pack(v)
	return string.pack("I1", v and 1 or 0)
end

local function float_pack(v)
	return string.pack("f", v)
end

local function v3_pack(v)
	return string.pack("fff", v[1], v[2], v[3])
end

local function mat_pack(v)
	local fmt = ""
	for _=1, 16 do fmt = fmt .. "f" end
	return string.pack(fmt, table.unpack(v))
end

return function(filename, mode)
	local ff = io.open(filename, mode)
	if ff == nil then
		error(string.format("filename open file, filename : %s, mode : %s", filename, mode))
	end

	local function write_pairs(k, v)
		assert(type(k) == "string", "must be string type")		
		
		local elemsize = #k

		local totalsize = elemsize
		if v then
			totalsize = totalsize + #v
		end
		
		ff:write(uint_pack(totalsize))		
		ff:write(uint_pack(elemsize))

		ff:write(k)
		if v then
			ff:write(v)
		end
	end

	local function write_separator()
		ff:write(uint_pack(0))
	end

	local function write_string(k, v)
		local s = string_pack(v)
		write_pairs(k, s)
	end

	local function write_uint(k, v)
		local i = uint_pack(v)
		write_pairs(k, i)
	end

	local function write_uint8(k, v)
		local u8 = uint8_pack(v)
		write_pairs(k, u8)
	end

	local function write_v3(k, v)
		local v3 = v3_pack(v)
		write_pairs(k, v3)
	end

	local function write_mat(k, v)
		local mat = mat_pack(v)
		write_pairs(k, mat)
	end

	local function write_float(k, v)
		local f = float_pack(v)
		write_pairs(k, f)
	end

	local function write_boolean(k, v)
		local b = boolean_pack(v)
		write_pairs(k, b)
	end

	local function write_struct(k, v, mapper)
		for kk, vv in pairs(v) do
			local packer = mapper[kk]
			if packer == nil then
				error(string.format("not support element : %s", kk))
			end

			packer(kk, vv)
		end

		write_separator()
	end

	local function write_array(k, v, mapper)
		for idx, vv in ipairs(v) do
			write_struct(idx, vv, mapper)
		end

		write_separator()
	end

	local function write_bounding(v)
			write_struct(v, {
			aabb = function (v) 
				write_struct(v, {
					min = write_v3,
					max = write_v3,
				})end,			
			sphere = function (v)
				return write_struct(v, {
					center = write_v3,
					radius = write_float,
				})
			end,
			})
	end	

	return write_struct(nil, nil, {
		srcfile = write_string,
		bounding = write_bounding,

		materials = function (k, v)
			return write_array(k, v, {
					name = write_string,
					textures = function (k, v) 
						return write_struct(k, v, {
							diffuse=write_string,
							ambient=write_string,
							specular=write_string,
							normals=write_string,
							shininess=write_string,
							lightmap=write_string,
						})
					end,
					colors = function (k, v)
						return write_struct(v, {
							diffuse=write_v3,
							specular=write_v3,
							ambient=write_v3,
						})
					end
				})
			end,
		groups = function(k, v)
			return write_array(k, v, {
				bounding	= write_bounding,
				name 		= write_string,
				vb = function(k, v) 
					return write_struct(k, v,{
					layout		= write_string,
					num_vertices= write_uint,
					vbraws		= function (k, v)
						for k, vv in pairs(v) do
							write_pairs(k, vv)
						end
					end,
					soa 		= write_boolean,})
				end,
				ib = function(k, v)
					return write_struct(k, v, {
						format		= write_uint8,
						num_indices	= write_uint,
						ibraw		= write_string,
					})
				end,
				primitives = function (k, v)
					return write_array(k, v, {
						bounding	= write_bounding,
						transform 	= write_mat,
						name 		= write_string,
						material_idx= write_uint,

						start_vertex= write_uint,
						num_vertices= write_uint,

						start_index = write_uint,
						num_indices = write_uint,
					}) 
				end,
			})
		end,
	})
end