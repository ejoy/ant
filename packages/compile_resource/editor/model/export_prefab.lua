local math3d = require "math3d"
local utility = require "editor.model.utility"
local serialize = import_package "ant.serialize"

local lfs = require "filesystem.local"
local fs = require "filesystem"

local invalid_chars<const> = {
    '<', '>', ':', '/', '\\', '|', '?', '*', ' ', '\t', '\r', '%[', '%]', '%(', '%)'
}

local replace_char<const> = '_'

local function fix_invalid_name(name)
    for _, ic in ipairs(invalid_chars) do
        name = name:gsub(ic, replace_char)
    end

    return name
end

local prefab = {}

local function create_entity(t)
    if t.parent then
        t.policy[#t.policy+1] = "ant.scene|scene_object"
        t.action = {set_parent = "#"..t.parent}
        t.data.scene = t.data.scene or {}
    end
    table.sort(t.policy)
    prefab[#prefab+1] = {
        policy = t.policy,
        data = t.data,
        action = t.action,
    }
    return #prefab
end

local function get_transform(node)
    if node.matrix then
        local s, r, t = math3d.srt(math3d.matrix(node.matrix))
        return {
            s = math3d.tovalue(s),
            r = math3d.tovalue(r),
            t = math3d.tovalue(t),
        }
    end

    local t, r = node.translation, node.rotation
    return {
        s = node.scale,
        r = r and {r[1], r[2], -r[3], -r[4]} or nil,     --r2l
        t = t and {t[1], t[2], -t[3]} or nil,            --r2l
    }
end

local STATE_TYPE = {
    visible     = 0x00000001,
    cast_shadow = 0x00000002,
    selectable  = 0x00000004,
}

local DEFAULT_STATE = STATE_TYPE.visible|STATE_TYPE.cast_shadow|STATE_TYPE.selectable

local function is_mirror_transform(trans)
    local s = math3d.srt(trans)
    s = math3d.tovalue(s)
    local n = 0
    for i=1, #s do
        if s[i] < 0 then
            n = n + 1
        end
    end

    return n == 1 or n == 3
end

local function duplicate_table(m)
    local t = {}
    for k, v in pairs(m) do
        if type(v) == "table" and getmetatable(v) == nil then
            t[k] = duplicate_table(v)
        else
            t[k] = v
        end
    end
    return t
end

local primitive_names = {
    "POINTS",
    "LINES",
    false, --LINELOOP, not support
    "LINESTRIP",
    "",         --TRIANGLES
    "TRISTRIP", --TRIANGLE_STRIP
    false, --TRIANGLE_FAN not support
}

local materials = {}

local function generate_material(mi, mode)
    local sname = primitive_names[mode+1]
    if not sname then
        error(("not support primitate state, mode:%d"):format(mode))
    end
    --defualt cull is CCW
    local function what_cull()

        return mi.material.state.CULL
    end

    local cullname = what_cull()

    local filename = mi.filename
    local key = filename:string() .. sname .. cullname

    local m = materials[key]
    if m == nil then
        if sname == "" and cullname == mi.material.state.CULL then
            m = mi
        else
            local f = mi.filename
            local basename = f:stem():string()

            local nm = duplicate_table(mi.material)
            local s = nm.state
            s.CULL = cullname
            if sname == "" then
                s.PT = nil
            else
                s.PT = sname
                basename = basename .. "_" .. sname
            end

            basename = basename .. "_" .. cullname
            filename = f:parent_path() / basename .. ".material"
            m = {
                filename = filename,
                material = nm
            }
        end

        materials[key] = m
    end

    return m
end

local function read_material_file(filename)
    local function read_file(fn)
        local f<close> = fs.open(fn)
        return f:read "a"
    end

    local mi = serialize.parse(filename, read_file(filename))
    if type(mi.state) == "string" then
        mi.state = serialize.parse(filename, read_file(fs.path(mi.state)))
    end
    return mi
end

local default_material_info = {
    filename = lfs.path "./materials/pbr_default_cw.material",
}

local function save_material(mi)
    if not lfs.exists(mi.filename) then
        utility.save_txt_file(mi.filename:string(), mi.material)
    end
end

local function create_mesh_node_entity(gltfscene, nodeidx, parent, exports, tolocalpath)
    local node = gltfscene.nodes[nodeidx+1]
    local transform = get_transform(node)
    local meshidx = node.mesh
    local mesh = gltfscene.meshes[meshidx+1]

    for primidx, prim in ipairs(mesh.primitives) do
        local meshname = mesh.name and fix_invalid_name(mesh.name) or ("mesh" .. meshidx)
        local materialfile
        local mode = prim.mode or 4
        if prim.material then
            if exports.material and #exports.material > 0 then
                local mi = assert(exports.material[prim.material+1])
                local materialinfo = generate_material(mi, mode)
                save_material(materialinfo)
                materialfile = materialinfo.filename
            else
                error(("primitive need material, but no material files output:%s %d"):format(meshname, prim.material))
            end
        else
            local default_material_path<const> = lfs.path "/pkg/ant.resources/materials/pbr_default.material"
            if default_material_info.material == nil then
                default_material_info.material = read_material_file(default_material_path)
            end
            local materialinfo = generate_material(default_material_info, mode)
            if materialinfo.filename ~= default_material_path then
                save_material(materialinfo)
                materialfile = materialinfo.filename
            else
                materialfile = default_material_path
            end
        end

        local meshfile = exports.mesh[meshidx+1][primidx]
        if meshfile == nil then
            error(("not found meshfile in export data:%d, %d"):format(meshidx+1, primidx))
        end

        local data = {
            scene       = {srt=transform or {}},
            mesh        = serialize.path(meshfile),
            material    = serialize.path(materialfile:string()),
            name        = node.name or "",
            state       = DEFAULT_STATE,
        }

        local policy = {
            "ant.general|name",
            "ant.render|render",
        }

        if node.skin and exports.skeleton and next(exports.animations) then
            local f = exports.skin[node.skin+1]
            if f == nil then
                error(("mesh need skin data, but no skin file output:%d"):format(node.skin))
            end
            data.skeleton = serialize.path(exports.skeleton)

            --skinning
            data.meshskin = serialize.path(f)
            policy[#policy+1] = "ant.animation|skinning"

            local lst = {}
            data.animation = {}
            for name, file in pairs(exports.animations) do
                local n = fix_invalid_name(name)
                data.animation[n] = serialize.path(file)
                lst[#lst+1] = n
            end
            table.sort(lst)
            data.animation_birth = lst[1]
            
			data.pose_result = false
			data._animation = {}
			data.anim_clips = {}
			data.keyframe_events = {}
			data.joint_list = {}
			data.skinning = {}
			data.material_setting = { skinning = "GPU"}

            policy[#policy+1] = "ant.animation|animation"
            policy[#policy+1] = "ant.animation|animation_controller.birth"
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
    local nname = node.name and fix_invalid_name(node.name) or ("node" .. nodeidx)
    return create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|scene_object"
        },
        data = {
            name = nname,
            scene = {srt=transform or {}},
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

return function(output, glbdata, exports, tolocalpath)
    prefab = {}

    local gltfscene = glbdata.info
    local sceneidx = gltfscene.scene or 0
    local scene = gltfscene.scenes[sceneidx+1]

    local rootid = create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|scene_object",
        },
        data = {
            name = scene.name or "Rootscene",
            scene = {srt={}}
        },
        --parent = "root",
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
        create_mesh_node_entity(gltfscene, nodeidx, parent, exports, tolocalpath)
    end
    utility.save_txt_file("./mesh.prefab", prefab)
end
