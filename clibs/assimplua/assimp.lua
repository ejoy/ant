dofile("libs/init.lua")
local assimp = require"assimplua"

local fbx_path = "D:/Engine/BnH/art/bnh/Assets/jingzhou/fbx/jingzhou_xiaowujian01.FBX"

local fbx_info = assimp.LoadFBXTest(fbx_path)

local function PrintNodeInfo(node, level)
    local space = string.rep(" ", level)

    print(space.."name: "..node.name)
    --print(space.."transform", node.Transform)

    local mesh = node.mesh
    for k, v in ipairs(mesh) do
        print(space.."mesh: "..k, "mesh count: ",#v.positions/3)
        print(space.."position",v.positions[1],v.positions[2],v.positions[3])
        print(space.."normal", v.normals[1], v.normals[2], v.normals[3])
        print(space.."texcoord0", v.texcoord0[1], v.texcoord0[2], v.texcoord0[3])
        print(space.."index", v.indices[1], v.indices[2], v.indices[3])
    end

    local children = node.children
    for _, v in ipairs(children) do
        PrintNodeInfo(v, level+4)
    end
end

--PrintNodeInfo(fbx_info, 1)