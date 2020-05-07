local fs = require "filesystem.local"

local fs_local = require "utility.fs_local"

local math3d = require "math3d"

local seri = require "serialize.serialize"

local def_class = {
    methodfunc = {
        init = true
    },
}
local resource_class = {
    class = def_class,
    type = "resource"
}

local pseudo_world = {
    eid_count = 0,
    _initargs = {},
    _class = {
        connection = {
            mount = {
                methodfunc = {
                    save = function (e)
                        return e.parent
                    end
                }
            }
        }
    },
    _typeclass = {},
    typemapper = {
        transform = {
            class = def_class,
            type = "transform",
        },
        srt = {
            class = def_class,
            type = "srt",
        }
    },

}

function pseudo_world:import_component(typename)
    local m = self.typemapper[typename]
    if m then
        return m.class
    end
end

function pseudo_world:create_entity(args)
    self.eid_count = self.eid_count + 1
    local eid = self.eid_count

    local function fetch_component_list(data)
        local t = {}
        for k, v in pairs(data) do
            if k ~= "parent" then
                t[#t+1] = k
                local m = self.typemapper[k]
                if m then
                    self._typeclass[v] = m.type
                    assert(k == "transform")
                    self._typeclass[v.srt] = self.typemapper.srt.type
                end
            end
        end

        table.sort(t)
        return t
    end

    self._initargs[eid] = {
        policy = args.policy,
        component = fetch_component_list(args.data),
        connection = {"mount"}, --only "mount"
    }
    pseudo_world[eid] = args.data
    return eid
end

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
    local connection
    if parent then
        policy[#policy+1] = "ant.scene|hierarchy_policy"
        connection = {
            {"mount", parent}
        }
    end

    if transform then
        policy[#policy+1] = "ant.scene|transform_policy"
    end

    return pseudo_world:create_entity {
        policy = policy,
        data = {
            transform   = transform,
            name        = name,
            scene_entity= true,
            parent      = parent,
        },
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
            srt={
                s = {1, 1, 1, 0},
                r = {0, 0, 0, 1},
                t = {0, 0, 0, 1},
            }
        },
        mesh        = meshres,
        material    = materialfile,
        name        = name,
        parent      = parent,
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

local meshcvt = require "compile_resource.mesh.convert"

local function sort_pairs(t)
    local s = {}
    for k in pairs(t) do
        s[#s+1] = k
    end

    table.sort(s)

    local n = 1
    return function ()
        local k = s[n]
        if k == nil then
            return
        end
        n = n + 1
        return k, t[k]
    end
end

return function(meshpath, materialfiles, meshfolder)
    fs.create_directories(meshfolder)

    local mc = fs_local.datalist(meshpath)
    local success, err = meshcvt(mc, meshpath, meshfolder, 
        function (filename) 
            if type(filename) == "string" then
                return fs.path(filename)
            end
            return filename
        end)
    if not success then
        error(("convert: %s, failed, error: %s"):format(meshpath:string(), err))
    end

    local cr_util = require "compile_resource.util"
    local meshscene = cr_util.read_embed_file(meshfolder / "main.index")

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
            local meshres = meshpath:string() .. ":" .. get_submesh_name(meshname, primidx)
            entities[#entities+1] = create_mesh_entity(parent, meshres, materialfiles[prim.material+1]:string(), meshname .. "." .. primidx)
        end
    end
    local prefabconetent = seri.prefab(pseudo_world, entities, {
        {mount="root"}
    })

    prefabconetent = prefabconetent:gsub("[^.]mesh:", " mesh: $resource ")
    prefabconetent = prefabconetent:gsub("material:", "material: $resource ")
    fs_local.write_file(fs.path(meshpath):replace_extension ".prefab", prefabconetent)
end