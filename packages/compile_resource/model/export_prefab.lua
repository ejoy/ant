local fs_local = import_package "ant.utility".fs_local
local sort_pairs = require "sort_pairs"
local math3d = require "math3d"
local stringify = import_package "ant.serialize".stringify

local prefab = {{}}
local conv = {}
local actions = prefab[1]

local function create_entity(t)
    local slot = #prefab
    if t.parent then
        t.policy[#t.policy+1] = "ant.scene|hierarchy_policy"
        actions[#actions+1] = {"mount", slot, t.parent}
        t.data["scene_entity"] = true
    end
    table.sort(t.policy)
    prefab[#prefab+1] = {
        policy = t.policy,
        data = t.data,
    }
    return slot
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

return function(output, glbdata, exports)
    prefab = {{}}
    conv = {}
    actions = prefab[1]

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

    local materialfiles, meshfiles, skinfiles = exports.material, exports.mesh, exports.skin
    local function get_submesh_name(meshidx, primidx)
        return meshfiles[meshidx][primidx][1]
    end

    local function export_entity(scensnodes, parent)
        for _, nodeidx in ipairs(scensnodes) do
            local node = gltfscene.nodes[nodeidx+1]
            local transform = get_transform(node)
            if node.mesh == nil then
                local newnode = create_entity {
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

                if node.children then
                    export_entity(node.children, newnode)
                end
            else
                local meshidx = node.mesh
                local mesh = gltfscene.meshes[meshidx+1]

                for primidx, prim in ipairs(mesh.primitives) do
                    local meshname = mesh.name or ("mesh" .. meshidx)
                    local mf
                    if materialfiles then
                        mf = materialfiles[prim.material+1]
                    else
                        error(("primitive need material, but no material files output:%s %d"):format(meshname, prim.material))
                    end
        
                    if mf == nil then
                        error(("material index not found in output material files:%d"):format(prim.material))
                    end

                    local meshskin
                    if mesh.skin then
                        local f = skinfiles[mesh.skin+1]
                        if f then
                            error(("mesh need skin data, but no skin file output:%d"):format(mesh.skin))
                        end

                        meshskin = proxy "resource" ("./" .. meshskin)
                    end

                    create_entity {
                        policy = {
                            "ant.general|name",
                            "ant.render|mesh",
                            "ant.render|render",
                        },
                        data = {
                            scene_entity= true,
                            can_render  = true,
                            transform   = transform,
                            mesh        = proxy "resource" ("./meshes/" .. get_submesh_name(meshidx+1, primidx)),
                            material    = proxy "resource" (mf),
                            meshskin    = meshskin,
                            name        = meshname .. "." .. primidx,
                        },
                        parent = parent,
                    }
                end
            end
        end
    end

    export_entity(scene.nodes, rootid)

    fs_local.write_file(output / "mesh.prefab", stringify(prefab, conv))
end
