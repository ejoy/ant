local fs = require "filesystem.local"

local fs_local = require "utility.fs_local"

local sort_pairs = require "sort_pairs"

local math3d = require "math3d"

local seri = require "serialize.serialize"
local seri_stringify = require "serialize.stringify"

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

local depth_cache = {}
local function get_depth(d)
    if d == 0 then
        return ""
    end
    local dc = depth_cache[d]
    if dc then
        return dc
    end

    local t = {}
    local tab<const> = "  "
    for i=1, d do
        t[#t+1] = tab
    end
    local dd = table.concat(t)
    depth_cache[d] = dd
    return dd
end

local function convertreal(v)
    local g = ('%.16g'):format(v)
    if tonumber(g) == v then
        return g
    end
    return ('%.17g'):format(v)
end

local PATTERN <const> = "%a%d/%-_."
local PATTERN <const> = "^["..PATTERN.."]["..PATTERN.."]*$"

local datalist = require "datalist"

local function stringify_basetype(v)
    local t = type(v)
    if t == 'number' then
        if math.type(v) == "integer" then
            return ('%d'):format(v)
        else
            return convertreal(v)
        end
    elseif t == 'string' then
        if v:match(PATTERN) then
            return v
        else
            return datalist.quote(v)
        end
    elseif t == 'boolean'then
        if v then
            return 'true'
        else
            return 'false'
        end
    elseif t == 'function' then
        return 'null'
    end
    error('invalid type:'..t)
end

local function seri_vector(v, lastv)
    lastv = lastv or 0
    if #v == 1 then
        return ("{%d, %d, %d, %d"):format(v[1], v[1], v[1], lastv)
    end

    if #v == 3 then
        return ("{%d, %d, %d, %d"):format(v[1], v[2], v[3], lastv)
    end

    if #v == 4 then
        return ("{%d, %d, %d, %d"):format(v[1], v[2], v[3], v[4])
    end

    error("invalid vector")
end

local function resource_type(prefix, v)
    assert(type(v) == "string")
    return prefix .. "$resource " .. stringify_basetype(v)
end

local typeclass = {
    mesh = function (depth, v)
        return get_depth(depth) .. resource_type("mesh: ", v)
    end,
    material = function (depth, v)
        return get_depth(depth) .. resource_type("material: ", v)
    end,
    transform = function (depth, v)
        assert(type(v) == "table")
        local tt = {get_depth(depth) .. "transform: $transform"}
        if v.srt then
            local seri_srt = get_depth(depth+1) .. "srt: $srt"
            local s, r, t = v.srt.s, v.srt.r, v.srt.t
            if s == nil or r == nil or t == nil then
                tt[#tt+1] = seri_srt .. " {}"
            else
                tt[#tt+1] = seri_srt
                if s then
                    tt[#tt+1] = get_depth(depth+2) .. "s:" .. seri_vector(s)
                end
                if r then
                    tt[#tt+1] = get_depth(depth+2) .. "r:" .. seri_vector(r)
                end
                if t then
                    tt[#tt+1] = get_depth(depth+2) .. "t:" .. seri_vector(t)
                end
            end
            
        end

        return table.concat(tt, "\n")
    end
}

local function seri_perfab(entities)
    local out = {"---"}
    out[#out+1] = "{mount 1 root}"
    local map = {}
    for idx, eid in ipairs(entities) do
        map[eid] = idx
    end
    for idx=2, #entities do
        local e = pseudo_world[entities[idx]]
        local connection = e.connection
        if connection then
            for _, c in ipairs(connection) do
                local target_eid = c[2]
                assert(pseudo_world[target_eid])
                out[#out+1] = ("{mount %d %d}"):format(idx, map[target_eid])
            end
        end
    end

    local depth = 0
    for _, eid in ipairs(entities) do
        local e = pseudo_world[eid]

        out[#out+1] = "---"
        out[#out+1] = "policy:"
        for _, pn in ipairs(e.policy) do
            out[#out+1] = get_depth(depth+1) .. pn
        end

        out[#out+1] = "data:"
        for compname, comp in sort_pairs(e.data) do
            local tc = typeclass[compname]
            if tc == nil then
                assert(type(comp) ~= "table" and type(comp) ~= "userdata")
                out[#out+1] = get_depth(depth+1) .. compname .. ":" .. stringify_basetype(comp)
            else
                out[#out+1] = tc(depth+1, comp)
            end
        end
    end

    return table.concat(out, "\n")
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

local meshcvt = require "compile_resource.mesh.convert"

local function create_meshfile(arguments, meshfolder)
    fs.create_directories(meshfolder)
    local c = {
        mesh_path = arguments:to_visualpath(arguments.input):string(),
        sourcetype = "glb",
        type = "mesh",
        config = arguments.config.mesh,
    }

    local outfile = meshfolder / arguments.input:stem():string() .. ".mesh"
    local cc = seri_stringify(c)
    fs_local.write_file(outfile, cc)
    print("output .mesh file:", outfile, ", success!")

    if _VERBOSE then
        print(cc)
    end
    return outfile
end

return function(arguments, materialfiles)
    local meshfolder = arguments.outfolder / "meshes"
    fs.create_directories(meshfolder)

    local meshpath = create_meshfile(arguments, meshfolder)

    local success, err = meshcvt(_, meshpath, meshfolder, 
        function (filename) 
            return arguments:to_localpath(fs.path(filename))
        end)
    if not success then
        error(("convert: %s, failed, error: %s"):format(meshpath:string(), err))
    end

    local cr_util = require "compile_resource.util"
    local meshscene = cr_util.read_embed_file(meshfolder / "main.index")

    fs.remove(meshfolder / "main.index")

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

    local visualmesh_path = arguments:to_visualpath(meshpath):string()
    for meshname, meshnode in sort_pairs(scene) do
        local parent = create_hierarchy_entity(meshname, get_transform(meshnode), rootid)
        entities[#entities+1] = parent
        for primidx, prim in ipairs(meshnode) do
            local meshres = visualmesh_path .. ":" .. get_submesh_name(meshname, primidx)
            local mf
            if materialfiles then
                mf = materialfiles[prim.material+1]
            else
                error(("primitive need material, but no material files output:%s %d"):format(meshname, prim.material))
            end

            if mf then
                mf = arguments:to_visualpath(mf):string()
            else
                error(("material index not found in output material files:%d"):format(prim.material))
            end
            entities[#entities+1] = create_mesh_entity(parent, meshres, mf, meshname .. "." .. primidx)
        end
    end
    local prefabconetent = seri_perfab(entities)

    local prefabpath = arguments.outfolder / "mesh.prefab"
    fs_local.write_file(prefabpath, prefabconetent)
    print("create .prefab: ", prefabpath:string(), ", success!")

    if _VERBOSE then
        print(prefabconetent)
    end
end