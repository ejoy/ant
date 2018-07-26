local assimp = require"assimplua"
local bgfx = require "bgfx"

local function PrintNodeInfo(node, level)
    local space = string.rep(" ", level)

    print(space.."name: "..node.name)
    print(space.."transform", node.transform)

    local mesh = node.mesh
    for k, v in ipairs(mesh) do
        print(space.."mesh: "..k, "mesh count: ",#v.vertices/9)
        print(space.."mat idx: ", v.material_idx)

        print(space.."position", v.vertices[1],v.vertices[2],v.vertices[3])
        print(space.."normal", v.vertices[4], v.vertices[5], v.vertices[6])
        print(space.."texcoord0", v.vertices[7], v.vertices[8], v.vertices[9])
        print(space.."index", #v.indices, v.indices[1], v.indices[2], v.indices[3])
    end

    local children = node.children
    for _, v in ipairs(children) do
        PrintNodeInfo(v, level+4)
    end
end


local function PrintMaterialInfo(material_info)
    print("material size", #material_info)
    for _, v in ipairs(material_info) do
        print("----------------------")
        print("name", v.name)
        print("ambient", v.ambient.r, v.ambient.g, v.ambient.b)
        print("diffuse", v.diffuse.r, v.diffuse.g, v.diffuse.b)
        print("specular", v.specular.r, v.specular.g, v.specular.b)
    end

end

local fbx_loader = {}


local math3d = require "math3d"
local stack = math3d.new()

local function HandleModelNode(material_info, model_node, parent_name, parent_transform)

    local name = model_node.name
    local transform
    if parent_transform then		
		--if the node is "GeometricTranslation" or similar, ignore transform
		transform = name:find("Geometric") and parent_transform 
										or stack(parent_transform, model_node.transform, "*T")
    else
        transform = model_node.transform
    end

    local mesh = model_node.mesh

    if mesh then
        for _, v in ipairs(mesh) do
            local material_idx = v.material_idx

            local material = material_info[material_idx]
            local prim = {}
            prim.name = v.name
            prim.parent = parent_name
            prim.transform = transform

            prim.startIndex = #material.ib_raw
            prim.startVertex = #material.vb_raw

            prim.numIndices = #v.indices
            prim.numVertex = #v.vertices

            for i = 1, #v.vertices do
                table.insert(material.vb_raw, v.vertices[i])
            end

            for i = 1, #v.indices do
                table.insert(material.ib_raw, v.indices[i])
            end

            table.insert(material.prim, prim)
        end
    end

    if model_node.children then
        for _, child in ipairs(model_node.children) do
            HandleModelNode(material_info, child, name, transform)
        end
    end
end

function fbx_loader.load(filepath)
    local path = require "filesystem.path"
    local ext = path.ext(filepath)
    if string.lower(ext) ~= "fbx" then
        return
	end

	local loadfbx_config = {
		--[[
			p3 for position and need 3 element(x, y, z)
			t20 for texcoord, need 2 element(u, v) and in channel 0
			t31 for texcoord, need 3 element(u, v, w) and in channel 1
			c30 for color, need 3 element(r,g,b) and in channel 0
		]] 
		layout = "p3|n|T|b|t20|c30",
		flags = {
			gen_normal = false,
			tangentspace = true,
		
			invert_normal = false,
			ib_32 = false,	-- if index num is lower than 65535
		},
		animation = {
			load_skeleton = true,
			ani_list = "all" -- or {"walk", "stand"}
		},
	}

	local meshgroup = assimp.LoadFBX(filepath, loadfbx_config)

	if meshgroup then
		local function create_decl(vb_layout)
			local decl = {}
			for v in vb_layout:gmatch("%w+") do 
				local type = v:sub(1, 1)
				local count = tonumber(v:sub(2, 2))
			
				if type == "p" then
					table.insert(decl, { "POSITION", count, "FLOAT" })
				elseif type == "n" then
					table.insert(decl, { "NORMAL", count, "FLOAT", true, false})
				elseif type == "T" then
					table.insert(decl, { "TANGENT", count, "FLOAT", true, false})
				elseif type == "b" then
					table.insert(decl, { "BITANGENT", count, "FLOAT", true, false})
				elseif type == "t" then	
					local channel = #v == 3 and v:sub(3, 3) or "0"
					table.insert(decl, { "TEXCOORD" .. channel, count, "FLOAT"})				
				elseif type == "c" then
					local channel = #v == 3 and v:sub(3, 3) or "0"
					table.insert(decl, { "COLOR" .. channel, count, "FLOAT"})
				end
			end
		
			return bgfx.vertex_decl(decl)
		end

		local group = meshgroup.group
		for _, g in ipairs(group) do
			local decl, stride = create_decl(g.vbLayout)
			g.vb = bgfx.create_vertex_buffer(g.vb_raw, decl)
			if g.ib_raw then
				g.ib = bgfx.create_index_buffer(g.ib_raw, g.ibFormat == 32 and "d" or nil)
			end
		end

		return meshgroup
	end
end

-- function fbx_loader.load(filepath)
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

return fbx_loader