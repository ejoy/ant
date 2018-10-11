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

local function create_vb(vb, streams)
	local handles = {}
	local decls = {}
	local vb_data = {"!", "", 1, nil}

	local function add_vb(layout, vbraw)
		local decl, stride = modelutil.create_decl(layout)
		vb_data[2], vb_data[4] = vbraw, vb.num_vertices * stride

		table.insert(decls, decl)
		table.insert(handles, bgfx.create_vertex_buffer(vb_data, decl))
	end

	if streams then
		local function gen_layout_vbraw_mapper(vb)
			local elems = layout_to_elems(vb.layout)		
			local vbraws = vb.vbraws
			assert(#vbraws == #elems)	
			local t = {}
			for idx, e in ipairs(elems) do				
				t[e] = vbraws[idx]
			end
	
			return t
		end

		local vbmapper = gen_layout_vbraw_mapper(vb)
		local function check_valid(vbmapper)
			local function elem_size(elem)
				assert(#elem == 6)				
				local count = elem:sub(2, 2)
				local internal_type = elem:sub(6, 6)

				local function get_internal_type_size(type)
					local typesize = {
						['f'] = 4,
						['i'] = 4,
						['u'] = 1,
					}

					local size = typesize[type]
					assert(size, "not support type")
					return size
				end

				return get_internal_type_size(internal_type) * count
			end
			
			for k, v in pairs(vbmapper) do
				local attrib = k:sub(1, 1)
				if attrib ~= "w" then
					assert(vb.num_vertices * elem_size(k) == #v)
				end
			end
		end
		check_valid(vbmapper)
		for _, s in ipairs(streams) do
			local function get_stream_layout(stream)
				local layout = vb.layout
				local stream_layout = {}

				local elems = layout_to_elems(layout)
				local debug_stream = ""
				local streamelems = get_stream_elems(stream)
				for _, m in ipairs(streamelems) do
					debug_stream = debug_stream .. m

					local function find_elem(m)
						for _, e in ipairs(elems) do
							assert(#e == 6)
							local attrib = e:sub(1, 1)
							if attrib == 'c' or attrib == 't' then
								local count = e:sub(3, 3)
								attrib = attrib .. count
							end

							if attrib == m then
								return e
							end
						end		
						return nil			
					end

					local e = find_elem(m)
					if e then
						table.insert(stream_layout, e)
					else
						error(string.format(
							"stream elem : %s in stream : %s, not match any vertex in layout : %s", 
							m, stream, layout))

					end					
				end

				if debug_stream ~= stream then
					log(string.format(
						"invalid stream element defined! stream is : %s, valid stream is : %s", 
						stream, debug_stream))
				end
				return table.concat(stream_layout, '|')
			end
	
			local slayout = get_stream_layout(s)
			-- should create from mesh convertor
			local function gen_vbraw(slayout)
				local elems = layout_to_elems(slayout)
				local vbraw = ""
				for _, e in ipairs(elems) do
					local v = vbmapper[e]					
					vbraw = vbraw .. v
				end
				return vbraw
			end
	
			local vbraw = gen_vbraw(slayout)
			add_vb(slayout, vbraw)
		end
	else
		local vbraws = vb.vbraws
		assert(#vbraws == 1)
		add_vb(vb.layout, vbraws[1])
	end

	vb.handles = handles
	vb.decls = decls
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
	local config = read_config(filepath)
	local meshgroup = load_from_source(filepath)
	print(filepath)
	if meshgroup then		
		for _, g in ipairs(meshgroup.groups) do
			create_vb(g.vb, get_streams(config))
			create_ib(g.ib)
		end

		return meshgroup
	end
end

return loader