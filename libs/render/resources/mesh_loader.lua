local require = import and import(...) or require

local bgfx = require "bgfx"

local util = {}

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

	local function gen_vb_flag(param)
		if param == nil then
			return nil
		end
		local flag = ""
		if param.calctangent then
			flag = flag .. "t"
		end

		return flag
	end

	local vb_decode = nil
	
	mesh_decode["VB \1"] = function(mesh, group, data, offset, param)
		offset = read_mesh_header(mesh, data, offset)
		local stride, numVertices		
		mesh.vdecl, stride, offset = bgfx.vertex_decl(data, offset)
		numVertices, offset = string.unpack("<I2", data, offset)

		vb_data[2] = data
		vb_data[3] = offset
		offset = offset + stride * numVertices
		vb_data[4] =  offset - 1

		local function decode()
			local flag = gen_vb_flag(param)
			local decl = mesh.vdecl
			if param and param.calctangent then
				vb_data[1] = decl
				local t_decl = bgfx.export_vertex_decl(decl)
				table.insert(t_decl, {"TANGENT", 3, "FLOAT"})
				decl = bgfx.vertex_decl(t_decl)
			end			

			local vb = bgfx.create_vertex_buffer(vb_data, decl, flag, ib_data)
			group.vb = vb
		end

		local function need_delay_decode()
			if param and param.calctangent then
				return group.ib == nil
			end
			return false
		end
		

		if need_delay_decode() then
			vb_data[1] = mesh.vdecl
			vb_decode = decode			
		else
			decode()
		end
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

		if vb_decode then
			vb_decode()
		end
		local tmp = {}
		for k,v in pairs(group) do
			group[k] = nil
			tmp[k] = v
		end
		table.insert(mesh.group, tmp)
		return offset
	end

	function util.load(filename, param)
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

			offset = decoder(mesh, group, data, offset + 4, param)
		end

		return mesh
	end
end

function util.unload(mesh)
	for _,group in ipairs(mesh.group) do
		bgfx.destroy(group.ib)
		bgfx.destroy(group.vb)
	end
end

-- function util.meshSubmit(mesh, id, prog)
-- 	local g = mesh.group
-- 	local n = #g
-- 	for i=1,n do
-- 		local group = g[i]
-- 		bgfx.set_index_buffer(group.ib)
-- 		bgfx.set_vertex_buffer(group.vb)
-- 		bgfx.submit(id, prog, 0, i ~= n)
-- 	end
-- end

-- function util.meshSubmitState(mesh, state, mtx)
-- 	bgfx.set_transform(mtx)
-- 	bgfx.set_state(state.state)

-- 	for _, texture in ipairs(state.textures) do
-- 		bgfx.set_texture(texture.stage,texture.sampler,texture.texture,texture.flags)
-- 	end

-- 	local g = mesh.group
-- 	local n = #g
-- 	for i=1,n do
-- 		local group = g[i]
-- 		bgfx.set_index_buffer(group.ib)
-- 		bgfx.set_vertex_buffer(group.vb)
-- 		bgfx.submit(state.viewId, state.program, 0, i ~= n)
-- 	end
-- end

-- function util.textureLoad(filename, info)
-- 	local f = assert(io.open(filename, "rb"))
-- 	local imgdata = f:read "a"
-- 	f:close()
-- 	local h = bgfx.create_texture(imgdata, info)
-- 	bgfx.set_name(h, filename)
-- 	return h
-- end

return util
