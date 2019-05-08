local gltf = import_package "ant.glTF"
local bgfx = require "bgfx"
local fs = require "filesystem"
local declmgr = import_package "ant.render".declmgr

local function init_buffers(scene, primitives, bindata)
	local buffers = scene.buffers
	local bufferviews = scene.bufferviews
	local accessors = scene.accessors

	local function create_buffer(accessor, decl)
		local bvidx = accessor.bufferview
		local bv = bufferviews[bvidx]

		local offset = accessor.byteoffset + bv.byteoffset
		local buffer = buffers[bv.buffer]
		
		local function get_data(buffer, bindata)
			local uri = buffer.uri
			if uri then
				local f = fs.open(uri)
				local content = f:read("a")
				f:close()
				return content
			end
			return bindata
		end

		local data = get_data(buffer, bindata)

		if decl then
			bv.handle = bgfx.create_vertex_buffer(decl, {"!", offset, bv.byte_length, data})
		else
			bv.handle = bgfx.create_index_buffer({offset, bv.byte_length, data})
		end
	end

	local gltfconverter = require "gltf.converter"

	for _, primitive in ipairs(primitives) do
		local bin = compile_primitive(scene, primitive, bindata)
		local bufferdesc = gltfconverter.arrange_buffer(bin, bindata)
		for _, bd in ipairs(bufferdesc) do
			local decl = declmgr.get(bd.decl_desc).handle
			
		end
		
	end
end

local function init_materials(scene, materials)

end

return function (filepath)
	local glbloader = gltf.glb
	local gltfloader = gltf.gltf
	local _, jsondata, bindata = glbloader.decode(filepath:string())
	local scene = gltfloader.decode(jsondata)

	init_buffers(scene)

	return {
		assetinfo = {
			handle = scene,
			bindata = bindata,
		}
	}
end