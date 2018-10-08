local function v3_unpack(v)
	local v1, v2, v3 = string.unpack("<fff", v)
	return {v1, v2, v3}
end

local function float_unpack(v)
	return string.unpack("<f", v)
end

local function uint_unpack(v)
	return string.unpack("<I4", v)
end

local function uint8_unpack(v)
	return string.unpack("<I1", v)
end

local function string_unpack(v)
	return v
end

local function boolean_unpack(v)
	local r = uint8_unpack(v)
	return r ~= 0
end

local function matrix_unpack(v)	
	local t = table.pack(string.unpack("<ffffffffffffffff", v))
	assert(#t == 17 and t.n == 17)
	t[17], t.n = nil, nil
	return t
end


-- local function split(s)
-- 	return s:match("([^:]+):(.*)$")
-- end

return function (filename)
	local function openfile(filename)
		local ff = assert(io.open(filename, "rb"))
		-- local content = ff:read("a")
		-- ff:close()
		-- local readit = 1
		-- local function read(sizeinbytes)
		-- 	local beg = readit
		-- 	readit = readit + sizeinbytes
		-- 	return content:sub(beg, readit - 1)
		-- end
		-- return function()
		-- 	local prefix = read(4)
		-- 	if prefix == nil or #prefix < 4 then
		-- 		return nil
		-- 	end

		-- 	local fullsize = string.unpack("<I4", prefix)
		-- 	if fullsize == 0 then
		-- 		return nil
		-- 	end
		-- 	local elemsize = string.unpack("<I4", read(4))			
		-- 	local elem = read(elemsize)
		-- 	local valuesize = fullsize - elemsize - 8
		-- 	local value = read(valuesize)
		-- 	return elem, value

		-- end
		local function read(size)
			if ff == nil then
				error("file is close and release, but still accessed, filename : ", filename)
			end
			return ff:read(size)
		end

		local function close()
			ff:close()
			ff = nil
		end

		return function (seek)
			if seek then
				return ff:seek(seek.where, seek.offset)
			end
			local prefix = read(4)	-- full content size and elem size
			if prefix == nil or #prefix < 4 then
				close()
				return nil
			end

			local fullsize = uint_unpack(prefix)
			if fullsize == 0 then
				return nil 
			end

			assert(fullsize > 4)
			local elemsize = uint_unpack(read(4))
			local elem = read(elemsize)
			local valuesize = fullsize - elemsize - 8
			local value = read(valuesize)			
			return elem, value
		end
	end
	
	local kvpairs = openfile(filename)

	local function struct_unpack(v, mapper)
		assert(v == nil or v == "")
		local t = {}		
		while true do
			local k, vv = kvpairs()
			if k == nil then
				break
			end
			assert(k)
			local unpacker = mapper[k]
			if unpacker == nil then
				error("not found unpacker, member is : " .. k)
			end			
			t[k] = mapper[k](vv)
		end
		return t
	end

	local function array_unpack(v, mapper)
		local r = {}
		while true do
			local t = struct_unpack(v, mapper)
			if t and next(t) then
				table.insert(r, t)
			else
				break
			end
		end
		return r
	end

	local function bounding_unpack(v)
		return struct_unpack(v, {
			aabb = function (v) 
				return struct_unpack(v, {
					min = v3_unpack,
					max = v3_unpack,
				})end,			
			sphere = function (v)
				return struct_unpack(v, {
					center = v3_unpack,
					radius = float_unpack,
				})
			end,
		})
	end

	local function get_group_mapper()
		return {
			bounding	= bounding_unpack,
			name 		= string_unpack,
			primitives = function (v)
				return array_unpack(v, {
					bounding= bounding_unpack,
					transform =matrix_unpack,
					name = string_unpack,
					material_idx = uint_unpack,

					start_vertex = uint_unpack,
					num_vertices = uint_unpack,

					start_index = uint_unpack,
					num_indices = uint_unpack,
				}) 
			end,
		}
	end

	local function get_mapper(version)
		local groupmapper = get_group_mapper()

		local root = {
			srcfile = string_unpack,
			bounding = bounding_unpack,

			materials = function (v)	
				return array_unpack(v, {
					name = string_unpack,
					textures = function (v) 
						return struct_unpack(v, {
							diffuse=string_unpack,
							ambient=string_unpack,
							specular=string_unpack,
							normals=string_unpack,
							shininess=string_unpack,
							lightmap=string_unpack,
						})
					end,
					colors = function (v)
						return struct_unpack(v, {
							diffuse=v3_unpack,
							specular=v3_unpack,
							ambient=v3_unpack,
						})
					end
				})
			end,
			groups = function(v)
				return array_unpack(v, groupmapper)
			end
		}

		if version >= (1 << 16) then
			groupmapper.vb = function(v) 
				return struct_unpack(v,{
				layout		= string_unpack,
				num_vertices= uint_unpack,
				vbraws		= function (v)
					local mapper = setmetatable({}, {__index=function (t, key)return string_unpack end})					
					return struct_unpack(v, mapper)
				end,
				soa 		= boolean_unpack,})
			end
			groupmapper.ib = function(v)
				return struct_unpack(v, {
					format		=uint8_unpack,
					num_indices	= uint_unpack,
					ibraw		= string_unpack,						
				})
			end
		elseif version == 0 then
			groupmapper.vb_layout	= string_unpack
			groupmapper.num_vertices= uint_unpack
			groupmapper.vbraw		= string_unpack

			groupmapper.ib_format	= uint8_unpack			
			groupmapper.num_indices = uint_unpack
			groupmapper.ibraw 		= string_unpack

			local groups = root.groups
			local function new_groups(v)
				local result = groups(v)
				assert(result.vb == nil)
				result.vb = {
					layout=assert(result.layout),
					num_vertices=assert(result.num_vertices),
					vbraws={assert(result.vbraw)},
					soa=false
				}

				assert(result.ib == nil)
				result.ib = {
					format=assert(result.ib_format),
					num_indices=assert(result.num_indices),
					ibraw=assert(result.ibraw),
				}
				return result
			end

			root.groups = new_groups
		end

		return root
	end

	local function get_version()
		local k, v = kvpairs()
		if k == "version" then
			return math.tointeger(v)
		end

		kvpairs({where="set"})	-- seek to begin
		return v
	end

	local mapper = get_mapper(get_version())

	-- actually, we can provide a common mapper for some common members, 
	-- like : bounding, transform, num_vertiecs, num_indices etc.	
	-- and when we need something special member mapper, we can provide from 
	-- mapper function. when a member not found in current level, it should 
	-- try to found in it's parent level, until it not found, and it will 
	-- raise an lua error(access to nil member).

	return struct_unpack(nil, mapper)
	-- return struct_unpack(nil, 
	-- {
	-- 	srcfile = string_unpack,
	-- 	bounding = bounding_unpack,

	-- 	materials = function (v)	
	-- 		return array_unpack(v, {
	-- 			name = string_unpack,
	-- 			textures = function (v) 
	-- 				return struct_unpack(v, {
	-- 					diffuse=string_unpack,
	-- 					ambient=string_unpack,
	-- 					specular=string_unpack,
	-- 					normals=string_unpack,
	-- 					shininess=string_unpack,
	-- 					lightmap=string_unpack,
	-- 				})
	-- 			end,
	-- 			colors = function (v)
	-- 				return struct_unpack(v, {
	-- 					diffuse=v3_unpack,
	-- 					specular=v3_unpack,
	-- 					ambient=v3_unpack,
	-- 				})
	-- 			end
	-- 		})
	-- 	end,

	-- 	groups = function(v)
	-- 		return array_unpack(v, {
	-- 			bounding	= bounding_unpack,
	-- 			name 		= string_unpack,
	-- 			vb 			= function(v) 
	-- 				return struct_unpack(v,{
	-- 				layout		= string_unpack,
	-- 				num_vertices= uint_unpack,
	-- 				vbraws		= function (v)
	-- 					local mapper = {}
	-- 					mapper.__index = function (t, key)
	-- 						return string_unpack
	-- 					end
	-- 					local t = array_unpack(v, mapper)
	-- 					assert(#t == 0)
	-- 					local sorted_t = {}
	-- 					for k in pairs(t) do
	-- 						table.insert(sorted_t, k)
	-- 					end
	-- 					local tt = {}
	-- 					for _, k in ipairs(sorted_t) do
	-- 						local v = t[k]
	-- 						table.insert(tt, v)
	-- 					end
	-- 					return tt
	-- 				end})
	-- 			end,
	-- 			ib			= function(v)
	-- 				return struct_unpack(v, {
	-- 					format		=uint8_unpack,
	-- 					num_indices	= uint_unpack,
	-- 					ibraw		= string_unpack,						
	-- 				})
	-- 			end,				
	-- 			primitives = function (v)
	-- 				return array_unpack(v, {
	-- 					bounding= bounding_unpack,
	-- 					transform =matrix_unpack,
	-- 					name = string_unpack,
	-- 					material_idx = uint_unpack,

	-- 					start_vertex = uint_unpack,
	-- 					num_vertices = uint_unpack,

	-- 					start_index = uint_unpack,
	-- 					num_indices = uint_unpack,
	-- 				}) 
	-- 			end,
	-- 		})
	-- 	end,
	-- })
end