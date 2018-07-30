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

        for i = 0, #v.vertices/9-1 do
            print(space.."position", v.vertices[i*9+1],v.vertices[i*9+2],v.vertices[i*9+3])
            print(space.."normal", v.vertices[i*9+4], v.vertices[i*9+5], v.vertices[i*9+6])
            print(space.."texcoord0", v.vertices[i*9+7], v.vertices[i*9+8], v.vertices[i*9+9])
        --    v.vertices[i*9+7] = 0.5
        --    v.vertices[i*9+8] = 0.5
         --   v.vertices[i*9+9] = 0.5
        end

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
local mat = math3d.ref "matrix"

local function HandleModelNode(material_info, model_node, parent_name, parent_transform)

    local name = model_node.name
    local transform
    if parent_transform then
        transform = parent_transform
        local start_pos = string.find(name, "Geometric")
        --if the node is "GeometricTranslation" or similar, ignore transform
        if not start_pos then
            transform = stack(parent_transform, model_node.transform, "*T")
        end
    else
        transform = model_node.transform
    end

    local mesh = model_node.mesh

    if mesh then
        for k, v in ipairs(mesh) do
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
    print("fbx loading: "..filepath)
    local path = require "filesystem.path"
    local ext = path.ext(filepath)
    if string.lower(ext) ~= "fbx" then
        return
    end

    local fbx_file = io.open(filepath, "rb")
    --local material_info, model_node = assimp.LoadFBX(filepath)
    if not fbx_file then
        print("fbx file does not exist: "..filepath)
        return
    end

    io.input(fbx_file)
    local file_data = fbx_file:read("*a")

    print("fbx length: "..tostring(#file_data))
    --read fbx file from memory
    local material_info, model_node = assimp.LoadFBXFromMem(file_data)
    io.close(fbx_file)

    if not material_info or not model_node then
        print("fbx load failed: "..filepath)
        return
    end

    --PrintNodeInfo(model_node, 1)
    --PrintMaterialInfo(material_info)

    for _, v in ipairs(material_info) do
        v.vb_raw = {}
        v.ib_raw = {}
        v.prim = {}
    end

    HandleModelNode(material_info, model_node)

    for _, v in ipairs(material_info) do
        --local data_string = string.pack("s", table.unpack(v.vb_raw))
        local vdecl, stride = bgfx.vertex_decl {
            { "POSITION", 3, "FLOAT" },
            { "NORMAL", 3, "FLOAT", true, false},
            { "TEXCOORD0", 3, "FLOAT"},
        }

        local vb_data = {"fffffffff", table.unpack(v.vb_raw)}

        v.vb = bgfx.create_vertex_buffer(vb_data, vdecl)
        v.ib = bgfx.create_index_buffer(v.ib_raw)
    end

    return {group = material_info}
end

return fbx_loader