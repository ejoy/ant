local fs_local = import_package "ant.utility".fs_local
local math3d = require "math3d"
local stringify = import_package "ant.serialize".stringify

local prefab = {}
local conv = {}

local function create_entity(t)
    if t.parent then
        t.policy[#t.policy+1] = "ant.scene|hierarchy_policy"
        t.action = {mount = t.parent}
        t.data["scene_entity"] = true
    end
    table.sort(t.policy)
    prefab[#prefab+1] = {
        policy = t.policy,
        data = t.data,
        action = t.action,
    }
    return #prefab
end

local function proxy(name)
    return function (v)
        local o = {v}
        conv[o] = {
            name = name,
            save = function()
                return v
            end
        }
        return o
    end
end

local function get_transform(node)
    if node.matrix then
        local s, r, t = math3d.srt(math3d.matrix(node.matrix))
        return proxy "transform" {
            srt = proxy "srt" {
                s = math3d.tovalue(s),
                r = math3d.tovalue(r),
                t = math3d.tovalue(t),
            }
        }
    end

    return proxy "transform" {
        srt = proxy "srt" {
            s = node.scale,
            r = node.rotation,
            t = node.translation,
        }
    }
end

local function create_mesh_node_entity(gltfscene, nodeidx, parent, exports)
    local node = gltfscene.nodes[nodeidx+1]
    local transform = get_transform(node)
    local meshidx = node.mesh
    local mesh = gltfscene.meshes[meshidx+1]

    for primidx, prim in ipairs(mesh.primitives) do
        local meshname = mesh.name or ("mesh" .. meshidx)
        local materialfile
        if exports.material then
            materialfile = exports.material[prim.material+1]
        else
            error(("primitive need material, but no material files output:%s %d"):format(meshname, prim.material))
        end

        if materialfile == nil then
            error(("material index not found in output material files:%d"):format(prim.material))
        end

        local meshfile = exports.mesh[meshidx+1][primidx]
        if meshfile == nil then
            error(("not found meshfile in export data:%d, %d"):format(meshidx+1, primidx))
        end
        local data = {
            scene_entity= true,
            can_render  = true,
            transform   = transform,
            mesh        = proxy "resource" (meshfile:string()),
            material    = proxy "resource" (materialfile:string()),
            name        = meshname .. "." .. primidx,
        }

        local policy = {
            "ant.general|name",
            "ant.render|mesh",
            "ant.render|render",
        }

        local meshskin
        if node.skin then
            local f = exports.skin[node.skin+1]
            if f == nil then
                error(("mesh need skin data, but no skin file output:%d"):format(node.skin))
            end

            meshskin = proxy "resource" (f:string())
        end

        if meshskin then
            if exports.skeleton == nil then
                error("mesh has skin info, but skeleton not export correctly")
            end

            data.skeleton = proxy "resource" (exports.skeleton:string())

            --skinning
            data.meshskin = meshskin
            policy[#policy+1] = "ant.animation|skinning"

            --animation
            if #exports.animations > 0 then
                local anilist = {}
                for _, anifile in ipairs(exports.animations) do
                    local stem = anifile:stem()
                    anilist[stem:string()] = proxy "resource"(anifile:string())
                end
                data.animation = {
                    anilist = anilist,
                }
                data.animation_birth = exports.animations[1]:stem():string()
                policy[#policy+1] = "ant.animation|animation"
                policy[#policy+1] = "ant.animation|animation_controller.birth"
            end
        end

        create_entity {
            policy = policy,
            data = data,
            parent = parent,
        }
    end
end

local function create_node_entity(gltfscene, nodeidx, parent)
    local node = gltfscene.nodes[nodeidx+1]
    local transform = get_transform(node)
    return create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|transform_policy"
        },
        data = {
            name = node.name or ("node" .. nodeidx),
            scene_entity = true,
            transform = transform,
        },
        parent = parent,
    }
end

local function find_mesh_nodes(gltfscene, scenenodes)
    local meshnodes = {}
    for _, nodeidx in ipairs(scenenodes) do
        local node = gltfscene.nodes[nodeidx+1]
        if node.children then
            local c_meshnodes = find_mesh_nodes(gltfscene, node.children)
            for ni, l in pairs(c_meshnodes) do
                l[#l+1] = nodeidx
                assert(meshnodes[ni] == nil)
                meshnodes[ni] = l
            end
        end
        if node.mesh then
            assert(node.children == nil)
            local meshlist = {}
            assert(meshnodes[nodeidx] == nil)
            meshnodes[nodeidx] = meshlist

            meshlist[#meshlist+1] = nodeidx
        end
    end

    return meshnodes
end

return function(output, glbdata, exports)
    prefab = {}
    conv = {}

    local gltfscene = glbdata.info
    local scene = gltfscene.scenes[gltfscene.scene+1]
    local rootid = create_entity {
        policy = {
            "ant.general|name",
        },
        data = {
            name = scene.name or "Rootscene",
        },
        parent = "root",
    }

    local meshnodes = find_mesh_nodes(gltfscene, scene.nodes)

    local C = {}
    for mesh_nodeidx, meshlist in pairs(meshnodes) do
        local parent = rootid
        for i=#meshlist, 2, -1 do
            local nodeidx = meshlist[i]
            local p = C[nodeidx]
            if p then
                parent = p
            else
                parent = create_node_entity(gltfscene, nodeidx, parent)
                C[nodeidx] = parent
            end
        end

        local nodeidx = meshlist[1]
        assert(C[nodeidx] == nil)
        C[nodeidx] = parent
        assert(nodeidx == mesh_nodeidx)
        create_mesh_node_entity(gltfscene, nodeidx, parent, exports)
    end
    fs_local.write_file(output / "mesh.prefab", stringify(prefab, conv))
end
