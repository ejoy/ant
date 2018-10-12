--luacheck: globals log

local log = log and log(...) or print

local bgfx = require "bgfx"

local fs = require "filesystem"
local path = require "filesystem.path"
local modelutil = require "modelloader.util"

local loader = {}

local function load_from_source(filepath)
	path.create_dirs(path.parent(path.join("cache", filepath)))
	local antmeshloader = require "modelloader.antmeshloader"
	return antmeshloader(path.remove_ext(filepath))
end

local function read_config(filepath)
	local lkfile = path.replace_ext(filepath, "lk")
	if fs.exist(lkfile) then
		local rawtable = require "asset.rawtable"
		local t = rawtable(lkfile)
		return t.config
	end

	
	return modelutil.default_config()
end

local function layout_to_elems(layout)
	local t = {}
	for m in layout:gmatch("%w+") do
		table.insert(t, m)
	end
	return t
end

local function get_stream_elems(s)
	local t = {}
	for m in s:gmatch("[pnTbtcwi]%d?") do
		table.insert(t, m)
	end
	return t	
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

local function get_streams(config)
	if config.animation.cpu_skinning then
		local streams = {}
		for _, s in ipairs(config.stream) do
			local selems = get_stream_elems(s)
			local function find_idx(name)
				for idx, se in ipairs(selems) do
					if se == name then
						return idx
					end
				end

				return nil
			end
			
			for _, name in ipairs{'i', 'w'} do
				local idx = find_idx(name)
				if idx then
					table.remove(selems, idx)
				end
			end

			if next(selems) then
				table.insert(streams, table.concat(selems))
			end
		end

		return streams
	end

	return config.stream
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