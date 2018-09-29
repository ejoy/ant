--luacheck: globals log

local log = log and log(...) or print

local bgfx = require "bgfx"

local fs = require "filesystem"
local path = require "filesystem.path"

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

	local modelutil = require "modelloader.util"
	return modelutil.default_config()
end

local function layout_to_elems(layout)
	local t = {}
	for m in layout:gmatch("%w+") do
		table.insert(t, m)
	end
	return t
end

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

local function create_vb(vb, streams)
	local handles = {}
	local decls = {}
	local vb_data = {"!", "", 1, nil}

	local function add_vb(layout, vbraw)
		local decl, stride = create_decl(layout)
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
		for _, s in ipairs(streams) do
			local function get_stream_layout(stream)
				local layout = vb.layout
				local stream_layout = {}

				local elems = layout_to_elems(layout)

				local debug_stream = ""

				for m in stream:gmatch("[pnTbtcwi]%d?") do
					debug_stream = debug_stream .. m

					local function find_elem(m)
						for e in ipairs(elems) do
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
				for e in ipairs(elems) do
					vbraw = vbraw .. vbmapper[e]
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

function loader.load(filepath)
	local config = read_config(filepath)
	local meshgroup = load_from_source(filepath)
	print(filepath)
	if meshgroup then		
		for _, g in ipairs(meshgroup.groups) do
			create_vb(g.vb, config.stream)
			create_ib(g.ib)
		end

		return meshgroup
	end
end

-- function loader.load(filepath)
--     print(filepath)
--     local path = require "filesystem.path"
--     local ext = path.ext(filepath)
--     if string.lower(ext) ~= "fbx" then
--         return
--     end

--     local material_info, model_node = assimp.LoadFBX(filepath)
--     if not material_info or not model_node then
--         return
--     end

--     --PrintNodeInfo(model_node, 1)
--     --PrintMaterialInfo(material_info)

--     for _, v in ipairs(material_info) do
--         v.vb_raw = {}
--         v.ib_raw = {}
--         v.prim = {}
--     end

--     HandleModelNode(material_info, model_node)

--     for _, v in ipairs(material_info) do
--         --local data_string = string.pack("s", table.unpack(v.vb_raw))
--         local vdecl, stride = bgfx.vertex_decl {
--             { "POSITION", 3, "FLOAT" },
--             { "NORMAL", 3, "FLOAT", true, false},
--             { "TEXCOORD0", 3, "FLOAT"},
--         }

--         local vb_data = {"fffffffff", table.unpack(v.vb_raw)}
--         v.vb = bgfx.create_vertex_buffer(vb_data, vdecl)
--         v.ib = bgfx.create_index_buffer(v.ib_raw)
--     end

--     return {group = material_info}
-- end

return loader