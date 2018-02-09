local require = import and import(...) or require

local bgfx = require "bgfx"
local ant = require "lbgfx"

-- init
local framework = require "framework"
local shader_path

function framework.init()
	print("lbgfx framework.init")
	local path = {
		NOOP       = "dx9",
		DIRECT3D9  = "dx9",
		DIRECT3D11 = "dx11",
		DIRECT3D12 = "dx11",
		GNM        = "pssl",
		METAL      = "metal",
		OPENGL     = "glsl",
		OPENGLES   = "essl",
		VULKAN     = "spirv",
	}
	shader_path = "assets/shaders/".. (assert(path[ant.caps.rendererType])) .."/"
end

local util = {}

do
	local function load_shader(name)
		local filename = shader_path .. name .. ".bin"
		local f = assert(io.open(filename, "rb"))
		local data = f:read "a"
		f:close()
		local h = bgfx.create_shader(data)
		bgfx.set_name(h, filename)
		return h
	end

	local function load_shader_uniforms(name)
		local h = load_shader(name)
		local uniforms = bgfx.get_shader_uniforms(h)
		return h, uniforms
	end

	local function uniform_info(uniforms, handles)
		for _, h in ipairs(handles) do
			local name, type, num = bgfx.get_uniform_info(h)
			if uniforms[name] == nil then
				uniforms[name] = { handle = h, name = name, type = type, num = num }
			end
		end
	end

	local function programLoadEx(vs,fs, uniform)
		local vsid, u1 = load_shader_uniforms(vs)
		local fsid, u2
		if fs then
			fsid, u2 = load_shader_uniforms(fs)
		end
		uniform_info(uniform, u1)
		if u2 then
			uniform_info(uniform, u2)
		end
		return bgfx.create_program(vsid, fsid, true), uniform
	end

	function util.programLoad(vs,fs, uniform)
		if uniform then
			return programLoadEx(vs,fs, uniform)
		else
			local vsid = load_shader(vs)
			local fsid = fs and load_shader(fs)
			return bgfx.create_program(vsid, fsid, true)
		end
	end

	function util.computeLoad(cs)
		local csid = load_shader(cs)
		return bgfx.create_program(csid, true)
	end
end

do
	local mesh_decode = {}
	local vb_header = "<" .. string.rep("f", 4+6+16)
	local vb_data = { "!", "", nil, nil }
	local ib_data = { "", nil, nil }

	local function read_mesh_header(group, data, offset)
		local tmp = { string.unpack(vb_header, data, offset) }
		group.sphere = { table.unpack(tmp,1,4) }
		group.aabb = { table.unpack(tmp,5,10) }
		group.obb = { table.unpack(tmp,11,26) }
		return tmp[27]
	end

	mesh_decode["VB \1"] = function(mesh, group, data, offset)
		offset = read_mesh_header(mesh, data, offset)
		local stride, numVertices
		mesh.vdecl, stride, offset = bgfx.vertex_decl(data, offset)
		numVertices, offset = string.unpack("<I2", data, offset)
		vb_data[2] = data
		vb_data[3] = offset
		offset = offset + stride * numVertices
		vb_data[4] =  offset - 1
		group.vb = bgfx.create_vertex_buffer(vb_data, mesh.vdecl)
		return offset
	end

	mesh_decode["IB \0"] = function(mesh, group, data, offset)
		local numIndices
		numIndices, offset = string.unpack("<I4", data, offset)
		ib_data[1] = data
		ib_data[2] = offset
		offset = offset + numIndices * 2
		ib_data[3] = offset - 1
		group.ib = bgfx.create_index_buffer(ib_data)
		return offset
	end

	mesh_decode["IBC\0"] = function(mesh, group, data, offset)
		local numIndices, size
		numIndices, size, offset = string.unpack("<I4I4", data, offset)
		local endp = offset + size
		group.ib = bgfx.create_index_buffer_compress(data, offset, endp -1)
		return endp
	end

	mesh_decode["PRI\0"] = function(mesh, group, data, offset)
		local material, num
		material, num, offset = string.unpack("<s2I2", data, offset)	-- no used
		group.prim = {}
		for i=1,num do
			local p = {}
			p.name, p.startIndex, p.numIndices, p.startVertex, p.numVertices, offset = string.unpack("<s2I4I4I4I4", data, offset)
			offset = read_mesh_header(p, data, offset)
			table.insert(group.prim, p)
		end
		local tmp = {}
		for k,v in pairs(group) do
			group[k] = nil
			tmp[k] = v
		end
		table.insert(mesh.group, tmp)
		return offset
	end

	function util.meshLoad(filename)
		local f = assert(io.open(filename,"rb"))
		local data = f:read "a"
		f:close()
		local mesh = { group = {} }
		local offset = 1
		local group = {}
		while true do
			local tag = data:sub(offset, offset+3)
			if tag == "" then
				break
			end
			local decoder = mesh_decode[tag]
			if not decoder then
				error ("Invalid tag " .. tag)
			end
			offset = decoder(mesh, group, data, offset + 4)
		end

		return mesh
	end
end

function util.meshUnload(mesh)
	for _,group in ipairs(mesh.group) do
		bgfx.destroy(group.ib)
		bgfx.destroy(group.vb)
	end
end

function util.meshSubmit(mesh, id, prog)
	local g = mesh.group
	local n = #g
	for i=1,n do
		local group = g[i]
		bgfx.set_index_buffer(group.ib)
		bgfx.set_vertex_buffer(group.vb)
		bgfx.submit(id, prog, 0, i ~= n)
	end
end

function util.meshSubmitState(mesh, state, mtx)
	bgfx.set_transform(mtx)
	bgfx.set_state(state.state)

	for _, texture in ipairs(state.textures) do
		bgfx.set_texture(texture.stage,texture.sampler,texture.texture,texture.flags)
	end

	local g = mesh.group
	local n = #g
	for i=1,n do
		local group = g[i]
		bgfx.set_index_buffer(group.ib)
		bgfx.set_vertex_buffer(group.vb)
		bgfx.submit(state.viewId, state.program, 0, i ~= n)
	end
end

function util.textureLoad(filename, info)
	local f = assert(io.open(filename, "rb"))
	local imgdata = f:read "a"
	f:close()
	local h = bgfx.create_texture(imgdata, info)
	bgfx.set_name(h, filename)
	return h
end

return util
