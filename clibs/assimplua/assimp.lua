dofile("libs/init.lua")
local assimp = require"assimplua"


local function PrintNodeInfo(node, level)
    local space = string.rep(" ", level)

    print(space.."name: "..node.name)
    print(space.."transform", node.transform)

    local mesh = node.mesh
    for k, v in ipairs(mesh) do
        print(space.."mesh: "..k, "mesh count: ",#v.positions/3)
        print(space.."mat idx: ", v.material_idx)

        print(space.."position", #v.positions, v.positions[1],v.positions[2],v.positions[3])
        print(space.."normal", #v.normals, v.normals[1], v.normals[2], v.normals[3])
        print(space.."texcoord0", #v.texcoord0, v.texcoord0[1], v.texcoord0[2], v.texcoord0[3])
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

function fbx_loader.load(filepath)
    local material_info, mesh_info = assimp.LoadFBX(filepath)

    PrintNodeInfo(mesh_info, 1)
    PrintMaterialInfo(material_info)

end

return fbx_loader