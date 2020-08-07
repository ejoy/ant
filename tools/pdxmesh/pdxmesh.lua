--[[

From : https://forum.paradoxplaza.com/forum/threads/import-export-paradox-mesh-tool.1009625/

.mesh file format
========================================================================================================================
    header    (@@b@ for binary, @@t@ for text)
    pdxasset    (int)  number of assets?
        object    (object)  parent item for all 3D objects
            shape    (object)
                ...  multiple shapes, used for meshes under different node transforms
            shape    (object)
                mesh    (object)
                    ...  multiple meshes per shape, used for different material IDs
                mesh    (object)
                    ...
                mesh    (object)
                    p    (float)  verts
                    n    (float)  normals
                    ta    (float)  tangents
                    u0    (float)  UVs
                    tri    (int)  triangles
                    aabb    (object)
                        min    (float)  min bounding box
                        max    (float)  max bounding box
                    material    (object)
                        shader    (string)  shader name
                        diff    (string)  diffuse texture
                        n    (string)  normal texture
                        spec    (string)  specular texture
                    skin    (object)
                        bones    (int)  num skin influences
                        ix    (int)  skin bone ids
                        w    (float)  skin weights
                skeleton    (object)
                    bone    (object)
                        ix    (int)  index
                        pa    (int)  parent index, omitted for root
                        tx    (float)  transform, 3*4 matrix
        locator    (object)  parent item for all locators
            node    (object)
                p    (float)  position
                q    (float)  quarternion
                pa    (string)  parent
]]

--local print_r = require "print_r"

local function readfile(filename)
	local f = assert(io.open(filename, "rb"))
	local content = f:read "a"
	f:close()
	return content
end

local function parse_data(content, pos)
	local t, n, pos = string.unpack("<c1i", content, pos)
	local result
	if t == "i" or t == "f" then
		result = {}
		local fmt = "<" .. t
		for i = 1, n do
			result[i], pos = string.unpack(fmt, content, pos)
		end
	elseif t == "s" then
		assert(n == 1, "Multiple strings")
		result, pos = string.unpack("<s4", content, pos)
		if result:byte(-1) == 0 then
			result = result:sub(1, -2)
		end
	else
		error ("Unknown type " .. t)
	end
	return result, pos
end

local function parse_object(content, pos)
	local _, npos = content:find("^%[+", pos)
	npos = npos + 1
	local depth = npos - pos
	local name
	name, pos = string.unpack("z", content, npos)
	return name, depth, pos
end

local function parse(content, pos, list)
	local c = content:sub(pos, pos)
	if c == "!" then
		local key, value
		key, pos = string.unpack("s1", content, pos+1)
		value, pos = parse_data(content, pos)
		local tree = list[list.depth]
		tree[key] = value
	elseif c == '[' then
		local name, depth
		name, depth, pos = parse_object(content, pos)
		if depth < list.depth then
			list.depth = depth
		else
			assert(depth == list.depth)
		end
		local tree = list[depth]
		local child = {}
		tree[name] = child
		depth = depth + 1
		list.depth = depth
		list[depth] = child
	else
		assert(c == "", "Unknown tag " .. c)
		return
	end
	return pos
end

local function parse_all(content)
	assert( content:sub(1, 4) == "@@b@" )

	local pos = 5
	local root = {}
	local depth_list = { depth = 1, root }

	repeat
		pos = parse(content, pos, depth_list)
	until pos == nil

	return depth_list[1]
end

local webgltype = {
	H = 5123, -- UNSIGNED_SHORT
	f = 5126, -- FLOAT
}

local typeinfo = {
	tri = {
		componentType = 'H',
		type = "SCALAR",
		n = 1,
		target = 34963, -- ELEMENT_ARRAY_BUFFER
	},
	p = {
		componentType = 'f',
		type = "VEC3",
		n = 3,
		target = 34962, -- ARRAY_BUFFER
	},
	n = {
		componentType = 'f',
		type = "VEC3",
		n = 3,
		target = 34962, -- ARRAY_BUFFER
	},
	ta = {
		componentType = 'f',
		type = "VEC4",
		n = 4,
		target = 34962, -- ARRAY_BUFFER
	},
	u0 = {
		componentType = 'f',
		type = "VEC2",
		n = 2,
		target = 34962, -- ARRAY_BUFFER
	},
}

local function quote(v)
	if type(v) == "string" then
		return '"' .. v .. '"'
	else
		return tostring(v)
	end
end

local function write_map(f, obj, level)
	local is_array = #obj > 0
	local indent = string.rep("  ", level)
	local next_indent = string.rep("  ", level+1)
	local sep = false

	if is_array then
		f:write("[\n")
		for k,v in pairs(obj) do
			if sep then
				f:write(",\n")
			end
			f:write(next_indent)
			if type(v) ~= "table" then
				f:write(string.format("%s", quote(v)))
			else
				write_map(f, v, level+1)
			end
			sep = true
		end
		f:write(indent, "]")
	else
		f:write("{\n")
		for k,v in pairs(obj) do
			if sep then
				f:write(",\n")
			end
			f:write(next_indent, string.format('"%s" : ', k))
			if type(v) ~= "table" then
				f:write(string.format("%s", quote(v)))
			else
				write_map(f, v, level+1)
			end
			sep = true
		end
		f:write(indent, "}")
	end
end

local function write_json(obj, filename)
	local f = assert(io.open(filename, "wb"))
	write_map(f, obj, 0)
	f:close()
end

local function to_gltf(obj, filename)
	local buffers = { size = 0 }
	local accessors = {}
	local bufferViews = {}
	local function gen_accessors(mesh, typename)
		local data = mesh[typename]
		if not data then
			return nil
		end
		local info = typeinfo[typename]
		local d = {}
		local fmt = "<" .. info.componentType
		for idx, v in ipairs(data) do
			d[idx] = fmt:pack(v)
		end
		local view = #buffers
		local blob = table.concat(d)
		local blob_aligned = blob
		do
			local length = #blob
			local padding = 4 - length % 4
			if padding ~=4 then
				blob_aligned = blob .. string.rep("\0", padding)
			end
		end
		buffers[view+1] = blob_aligned
		local accessor = {
			bufferView = view,
			componentType = webgltype[info.componentType],
			count = #data // info.n ,
			type = info.type,
		}
		accessors[view+1] = accessor
		local bufferView = {
			buffer = 0,
			byteLength = #blob,
			byteOffset = buffers.size,
			target = info.target,
		}
		buffers.size = buffers.size + #blob_aligned
		bufferViews[view+1] = bufferView
		if typename == "p" then
			local aabb = mesh.aabb
			if aabb then
				accessor.min = aabb.min
				accessor.max = aabb.max
			end
		end
		return view
	end
	local function gen_buffers(mesh)
		local r = {
			attributes = {},
			indices = nil,
			mode = 4, -- TRIANGLES(4)
		}
		r.indices = gen_accessors(mesh, "tri")
		r.attributes.POSITION = gen_accessors(mesh, "p")
		r.attributes.NORMAL = gen_accessors(mesh, "n")
		r.attributes.TANGENT = gen_accessors(mesh, "ta")
		r.attributes.TEXCOORD_0 = gen_accessors(mesh, "u0")
		return r
	end

	local nodes_index = {}
	local nodes = {}
	local meshes = {}
	local gltf = {
		asset = {
			generator = "PDX mesh to gltf",
			version = "2.0",
		},
		scene = 0,
		scenes = {
			{ nodes = nodes_index },
		},
		nodes = nodes,
		meshes = meshes,
		buffers = {},
		bufferViews = bufferViews,
		accessors = accessors,
	}
	local index = 0
	for name, object in pairs(obj.object) do
		nodes_index[index + 1] = index
		nodes[index + 1] = { mesh = index }
		meshes[index + 1] = {
			name = name,
			primitives = { gen_buffers(object.mesh) },
		}
		index = index + 1
	end

	local bin = table.concat(buffers)
	local binname = filename .. ".bin"
	gltf.buffers[1] = { byteLength = #bin, uri = binname }
	local binf = assert(io.open(binname, "wb"))
	binf:write(bin)
	binf:close()
	write_json(gltf, filename .. ".gltf")
end

local function main(filename)
	local content = readfile(filename)
	local name_no_ext = filename:match "(.*)%.mesh$"

	local r = parse_all(content)
	--todo: export anim/mat, etc
	to_gltf(r, name_no_ext)
end

main(...)
