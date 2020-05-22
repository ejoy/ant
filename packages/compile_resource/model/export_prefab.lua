local utilitypkg = import_package "ant.utility"
local fs_local = utilitypkg.fs_local

local sort_pairs = require "sort_pairs"
local seri_util = require "model.seri_util"

local math3d = require "math3d"
local thread = require "thread"
local export_meshbin = require "model.export_meshbin"


local pseudo_world = {
    eid_count = 0,
    create_entity = function (w, args)
        w.eid_count = w.eid_count + 1
        local eid = w.eid_count
        w[eid] = args
        return eid
    end
}

local function get_transform(node)
    if node.matrix then
        local s, r, t = math3d.srt(math3d.matrix(node.matrix))
        return {
                srt = {
                    s = math3d.tovalue(s),
                    r = math3d.tovalue(r),
                    t = math3d.tovalue(t),
            }
        }
    end

    if node.scale or node.rotation or node.translation then
        return {srt = {
            s = node.scale or {1, 1, 1, 0},
            r = node.rotation or {0, 0, 0, 1},
            t = node.translation or {0, 0, 0, 1}
        }}
    end
end

local function create_hierarchy_entity(name, transform, parent)
local policy = {
        "ant.general|name",
    }
    local data = {
        name        = name,
    }
    local connection
    if parent then
        policy[#policy+1] = "ant.scene|hierarchy_policy"
        connection = {
            {"mount", parent}
        }

        data["scene_entity"] = true
    end

    if transform then
        policy[#policy+1] = "ant.scene|transform_policy"
        data["scene_entity"] = true
    end

    return pseudo_world:create_entity {
        policy = policy,
        data = data,
        connection = connection,
    }
end

local function create_mesh_entity(parent, meshres, materialfile, name)
    local policy = {
        "ant.general|name",
        "ant.render|mesh",
        "ant.render|render",
    }

    local data = {
        scene_entity= true,
        can_render  = true,
        transform   = {
            srt={}
        },
        mesh        = meshres,
        material    = materialfile,
        name        = name,
    }

    local connection
    if parent then
        policy[#policy+1] = "ant.scene|hierarchy_policy"
        connection = {
            {"mount", parent}
        }
    end

    return pseudo_world:create_entity{
        policy = policy,
        data = data,
        connection = connection,
    }
end

return function(arguments, materialfiles, glbdata)
    local meshscene = export_meshbin(glbdata)
    if meshscene == nil then
        error("export meshbin failed")
    end
    local meshbinpath = arguments.outfolder / "mesh.meshbin"
    fs_local.write_file(meshbinpath, thread.pack(meshscene))

    local scene = meshscene.scenes[meshscene.scene]
    local function get_submesh_name(meshname, primidx)
        return table.concat({
            "scenes",
            meshscene.scene,
            meshname,
            primidx
        }, ".")
    end

    local rootid = create_hierarchy_entity(meshscene.scene)
    local entities = {
        rootid,
    }

    for meshname, meshnode in sort_pairs(scene) do
        local parent = create_hierarchy_entity(meshname, get_transform(meshnode), rootid)
        entities[#entities+1] = parent
        for primidx, prim in ipairs(meshnode) do
            local meshres = "./mesh.meshbin:" .. get_submesh_name(meshname, primidx)
            local mf
            if materialfiles then
                mf = materialfiles[prim.material+1]
            else
                error(("primitive need material, but no material files output:%s %d"):format(meshname, prim.material))
            end

            if mf == nil then
                error(("material index not found in output material files:%d"):format(prim.material))
            end
            entities[#entities+1] = create_mesh_entity(parent, meshres, mf:string(), meshname .. "." .. primidx)
        end
    end
    local prefabconetent = seri_util.seri_perfab(pseudo_world, entities)

    local prefabpath = arguments.outfolder / "mesh.prefab"
    fs_local.write_file(prefabpath, prefabconetent)
    print("create .prefab: ", prefabpath:string(), ", success!")

    if _VERBOSE then
        print(prefabconetent)
    end
end