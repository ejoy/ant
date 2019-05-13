local bgfx = require "bgfx"
local fs = require "filesystem"

local declmgr = import_package "ant.render".declmgr
local antmeshloader = require "antmeshloader"
local glbloader = require "glbloader"

local loader = {}

local function is_glb(meshfile)
	meshfile:seek("set", 0)
	local content = meshfile:read(4) 
	meshfile:seek("set", 0)
	return content == "glTF"
end

local function create_vb(vb)
	local handles = {}	
	local vb_data = {"!", "", 1, 0}

	local vbraws = vb.vbraws
	local num_vertices = vb.num_vertices
	for layout, vbraw in pairs(vbraws) do
		local decl = declmgr.get(layout)
		local declhandle, stride = decl.handle, decl.stride
		vb_data[2], vb_data[4] = vbraw, num_vertices * stride
		table.insert(handles, bgfx.create_vertex_buffer(vb_data, declhandle))
	end

	vb.handles 	= handles	
end

local function create_ib(ib)
	if ib then
		local ib_data = {"", 1, nil}
		local elemsize = ib.format == 32 and 4 or 2
		ib_data[1], ib_data[3] = ib.ibraw, elemsize * ib.num_indices
		ib.handle = bgfx.create_index_buffer(ib_data, elemsize == 4 and "d" or nil)
	end
end

function loader.load(filepath)
	if not __ANT_RUNTIME__ then
		assert(fs.exists(filepath .. ".lk"))
	end

	local meshfile = fs.open(filepath, "rb")

	if is_glb(meshfile) then
		return glbloader(meshfile)
	end

	local meshgroup = antmeshloader(meshfile)
	if meshgroup then
		for _, g in ipairs(meshgroup.groups) do
			create_vb(g.vb)
			create_ib(g.ib)
		end

		return meshgroup
	end
end
return loader
