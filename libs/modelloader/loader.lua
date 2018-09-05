local meshcreator = require "assimplua"
local bgfx = require "bgfx"

local fu = require "filesystem.util"
local fs = require "filesystem"
local path = require "filesystem.path"

local loader = {}

local function load_from_source(filepath, config)
	-- local antmeshfile = path.join("cache", path.replace_ext(filepath, "antmesh"))
	-- path.create_dirs(path.parent(antmeshfile))

	-- if fu.file_is_newer(filepath, antmeshfile) then		
	-- 	local ext = path.ext(filepath):lower()
	-- 	if ext == "fbx" then
	-- 		meshcreator.convert_FBX(filepath, antmeshfile, config)
	-- 	elseif ext == "bin" then
	-- 		meshcreator.convert_BGFXBin(filepath, antmeshfile, config)
	-- 	else 
	-- 		error(string.format("unknown ext : %s", ext))
	-- 	end
	-- end

	path.create_dirs(path.join("cache", filepath))
	local antmeshloader = require "modelloader.antmeshloader"
	return antmeshloader(filepath)
end

function loader.load(filepath)
	local modelutil = require "modelloader.util"
	local config = modelutil.default_config()

	local meshgroup = load_from_source(filepath, config)
	if meshgroup then
		local function create_decl(vb_layout)
			local decl = {}
			for v in vb_layout:gmatch("%w+") do 
				local function adjust_elem(e)
					local defelem = {'_', '3', '0', 'N', 'I', 'f'}					
					for i=1, #e do
						local c = v:sub(i, i)
						defelem[i] = c
					end
					return table.concat(defelem)
				end

				local e = adjust_elem(v)
				local function get_attrib(a)
					local t = {	p = "POSITION",	n = "NORMAL",T = "TANGENT",	b = "BITANGENT",
						i = "INDICES",	w = "WEIGHT",
						c = "COLOR", t = "TEXCOORD"
					}
					return assert(t[a])
				end
				local attrib = get_attrib(e:sub(1, 1))
				local num = tonumber(e:sub(2, 2))

				if attrib == "COLOR" or attrib == "TEXCOORD" then
					local channel = e:sub(3, 3)
					attrib = attrib .. channel
				end

				local function get_type(v)					
					local t = {	u = "UINT8", U = "UINT10", i = "INT16",
						h = "HALF",	f = "FLOAT",}
					return assert(t[v])
				end

				local normalize = e:sub(4, 4) == "n"
				local asint= e:sub(5, 5) == "i"
				local type = get_type(e:sub(6, 6))

				table.insert(decl, {attrib, num, type, normalize, asint})
			end
		
			return bgfx.vertex_decl(decl)
		end

		local groups = meshgroup.groups

		local vb_data = {"!", "", 1, nil}
		local ib_data = {"", 1, nil}

		for _, g in ipairs(groups) do
			local decl, stride = create_decl(g.vb_layout)
			vb_data[2], vb_data[4] = g.vbraw, g.num_vertices * stride
			
			g.vb = bgfx.create_vertex_buffer(vb_data, decl)
			if g.ibraw then
				local elemsize = g.ib_format == 32 and 4 or 2
				ib_data[1], ib_data[3] = g.ibraw, elemsize * g.num_indices
				g.ib = bgfx.create_index_buffer(ib_data, elemsize == 4 and "d" or nil)
			end
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