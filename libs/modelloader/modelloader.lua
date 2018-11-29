--luacheck: globals log, ignore log

local log = log and log(...) or print

local bgfx = require "bgfx"
local modelutil = require "modelloader.util"
local vfs = require "vfs"

local antmeshloader = require "modelloader.antmeshloader"
local cvtutil = require "fileconvert.util"

local loader = {}

local function load_from_source(filepath)
	assert(cvtutil.need_build(filepath))
	local validfile = vfs.realpath(filepath)
	return antmeshloader(validfile)
end

local function create_vb(vb)
	local handles = {}
	local decls = {}
	local vb_data = {"!", "", 1, 0}

	local vbraws = vb.vbraws
	local num_vertices = vb.num_vertices
	for layout, vbraw in pairs(vbraws) do
		local decl, stride = modelutil.create_decl(layout)
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

return loader