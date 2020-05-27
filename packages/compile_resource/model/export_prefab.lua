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
    if node.transform then
        return proxy "transform" {
            srt = proxy "matrix" (node.transform)
        }
    end
    if node.scale or node.rotation or node.translation then
        return proxy "transform" {
            srt = proxy "srt" {
                s = node.scale or {1, 1, 1, 0},
                r = node.rotation or {0, 0, 0, 1},
                t = node.translation or {0, 0, 0, 1}
            }
        }
    end
end

return function(output, meshscene, materialfiles)
    prefab = {{}}
    conv = {}
    actions = prefab[1]

    local scene = meshscene.scenes[meshscene.scene]
    local function get_submesh_name(meshname, primidx)
        return table.concat({
            "scenes",
            meshscene.scene,
            meshname,
            primidx
        }, ".")
    end

    local rootid = create_entity {
        policy = {
            "ant.general|name",
        },
        data = {
            name = meshscene.scene,
        },
        parent = "root",
    }
    for meshname, meshnode in sort_pairs(scene) do
        local transform = get_transform(meshnode)
        local parent
        if transform then
            parent = create_entity {
                policy = {
                    "ant.general|name",
                    "ant.scene|transform_policy"
                },
                data = {
                    name = meshname,
                    scene_entity = true,
                    transform = transform,
                },
                parent = rootid,
            }
        else
            parent = create_entity {
                policy = { "ant.general|name" },
                data = { name = meshname },
                parent = rootid,
            }
        end
        for primidx, prim in ipairs(meshnode) do
            local mf
            if materialfiles then
                mf = materialfiles[prim.material+1]
            else
                error(("primitive need material, but no material files output:%s %d"):format(meshname, prim.material))
            end

            if mf == nil then
                error(("material index not found in output material files:%d"):format(prim.material))
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
                    transform   = proxy "transform" {
                        srt = proxy "srt" {}
                    },
                    mesh        = proxy "resource" ("./mesh.meshbin:" .. get_submesh_name(meshname, primidx)),
                    material    = proxy "resource" (mf),
                    name        = meshname .. "." .. primidx,
                },
                parent = parent,
            }
        end
    end
    fs_local.write_file(output / "mesh.prefab", stringify(prefab, conv))
end
