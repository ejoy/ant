local bgfx = require "bgfx"
local fs = require "filesystem"
local vfs = require "vfs"

local antmeshloader = require "antmeshloader"

local loader = {}


-- need move to bgfx c module
local function create_decl(vb_layout)
	local decl = {}
	for e in vb_layout:gmatch("%w+") do 
		assert(#e == 6)
		local function get_attrib(e)
			local t = {	
				p = "POSITION",	n = "NORMAL", T = "TANGENT",	b = "BITANGENT",
				i = "INDICES",	w = "WEIGHT",
				c = "COLOR", t = "TEXCOORD",
			}
			local a = e:sub(1, 1)
			local attrib = assert(t[a])
			if attrib == "COLOR" or attrib == "TEXCOORD" then
				local channel = e:sub(3, 3)
				return attrib .. channel
			end

			return attrib
		end
		local attrib = get_attrib(e)
		local num = tonumber(e:sub(2, 2))

		local function get_type(v)					
			local t = {	
				u = "UINT8", U = "UINT10", i = "INT16",
				h = "HALF",	f = "FLOAT",
			}
			return assert(t[v])
		end

		local normalize = e:sub(4, 4) == "n"
		local asint= e:sub(5, 5) == "i"
		local type = get_type(e:sub(6, 6))

		table.insert(decl, {attrib, num, type, normalize, asint})
	end

	return bgfx.vertex_decl(decl)
end

local function load_from_source(filepath)
	if not fs.vfs then
		assert(vfs.type(filepath:string() .. ".lk") ~= nil)
	end
	return antmeshloader(filepath)
end

local function create_vb(vb)
	local handles = {}
	local decls = {}
	local vb_data = {"!", "", 1, 0}

	local vbraws = vb.vbraws
	local num_vertices = vb.num_vertices
	for layout, vbraw in pairs(vbraws) do
		local decl, stride = create_decl(layout)
		vb_data[2], vb_data[4] = vbraw, num_vertices * stride

		table.insert(decls, decl)
		table.insert(handles, bgfx.create_vertex_buffer(vb_data, decl))
	end

	vb.handles 	= handles
	vb.decls 	= decls
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
	local meshgroup = load_from_source(filepath)	
	if meshgroup then
		for _, g in ipairs(meshgroup.groups) do
			create_vb(g.vb)
			create_ib(g.ib)
		end

		return meshgroup
	end
end

loader.create_decl = create_decl

return loader
