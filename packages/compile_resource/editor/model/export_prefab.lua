local math3d = require "math3d"
local utility = require "editor.model.utility"
local serialize = import_package "ant.serialize"

local lfs = require "filesystem.local"
local fs = require "filesystem"

local invalid_chars<const> = {
    '<', '>', ':', '/', '\\', '|', '?', '*', ' ', '\t', '\r', '%[', '%]', '%(', '%)'
}

local pattern_fmt<const> = ("[%s]"):format(table.concat(invalid_chars, ""))
local replace_char<const> = '_'

local function fix_invalid_name(name)
    return name:gsub(pattern_fmt, replace_char)
end

local prefab = {}

local function create_entity(t)
    if t.parent then
        t.mount = t.parent
        t.data.scene = t.data.scene or {}
    end
    table.sort(t.policy)
    prefab[#prefab+1] = {
        policy = t.policy,
        data = t.data,
        mount = t.mount,
    }
    return #prefab
end

local function get_transform(node)
    if node.matrix then
        local s, r, t = math3d.srt(math3d.matrix(node.matrix))
        local rr = math3d.tovalue(r)
        rr[3], rr[4] = -rr[3], -rr[4]
        local ttx, tty, ttz = math3d.index(t, 1, 2, 3)
        return {
            s = {math3d.index(s, 1, 2, 3)},
            r = rr,
            t = {ttx, tty, -ttz},
        }
    end

    local t, r = node.translation, node.rotation
    return {
        s = node.scale,
        r = r and {r[1], r[2], -r[3], -r[4]} or nil,     --r2l
        t = t and {t[1], t[2], -t[3]} or nil,            --r2l
    }
end

local DEFAULT_STATE = "main_view|selectable|cast_shadow"

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

local function find_node_animation(gltfscene, nodeidx, scenetree, animationfiles)
    if next(animationfiles) == nil then
        return
    end

    for _, ani in ipairs(gltfscene.animations) do
        for _, channel in ipairs(ani.channels) do
            local idx = nodeidx
            local targetidx = channel.target.node
            local found
            while idx do
                if idx == targetidx then
                    found = true
                    break
                end
                idx = scenetree[idx]
            end
            if found then
                local anifile = animationfiles[ani.name]
                if anifile == nil then
                    error(("node:%d, has animation, but not found in exports.animations: %s"):format(nodeidx, ani.name))
                end
                return anifile
            end
        end
    end
end

local function add_animation(gltfscene, exports, nodeidx, policy, data)
    --TODO: we need to check skin.joints is reference to skeleton node, to detect this mesh entity have animation or not
    --      we just give it animation info where it have skin info right now
    local node = gltfscene.nodes[nodeidx+1]
    if node.skin and next(exports.animations) and exports.skeleton then
        if node.skin then
            local f = exports.skin[node.skin+1]
            if f == nil then
                error(("mesh need skin data, but no skin file output:%d"):format(node.skin))
            end
            data.skeleton = serialize.path(exports.skeleton)

            --skinning
            data.meshskin = serialize.path(f)
            policy[#policy+1] = "ant.animation|skinning"

            data.material_setting = { skinning = "GPU"}
        -- else
        --     policy[#policy+1] = "ant.scene|slot"
        --     local idx = assert(exports.node_joints[nodeidx], "node index is not one of the skeleton struct:" .. nodeidx)
        --     local function get_joint_name(jidx)
        --         local skemodule = require "hierarchy".skeleton
        --         local handle = skemodule.new()
        --         handle:load(exports.skeleton)
        --         return handle:joint_name(jidx)
        --     end
        --     data.slot = {follow_flag=3, joint_name=get_joint_name(idx)}
        end

        data.animation = {}
        local anilst = {}
        for name, file in pairs(exports.animations) do
            local n = fix_invalid_name(name)
            anilst[#anilst+1] = n
            data.animation[n] = serialize.path(file)
        end
        table.sort(anilst)
        data.animation_birth = anilst[1]
        
        data.pose_result = false
        data._animation = {anim_clips = {}, keyframe_events = {}, joint_list = {}}
        data.skinning = {}

        policy[#policy+1] = "ant.animation|animation"
        policy[#policy+1] = "ant.animation|animation_controller.birth"
    end
end

local function create_mesh_node_entity(gltfscene, nodeidx, parent, exports)
    local node = gltfscene.nodes[nodeidx+1]
    local transform = get_transform(node)
    local meshidx = node.mesh
    local mesh = gltfscene.meshes[meshidx+1]

    local entity
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
            filter_state= DEFAULT_STATE,
        }

        local policy = {
            "ant.general|name",
            "ant.render|render",
        }

        add_animation(gltfscene, exports, nodeidx, policy, data)

        --TODO: need a mesh node to reference all mesh.primitives, we assume primitives only have one right now
        entity = create_entity {
            policy = policy,
            data = data,
            parent = parent,
        }
    end
    return entity
end

local function create_node_entity(gltfscene, nodeidx, parent, exports)
    local node = gltfscene.nodes[nodeidx+1]
    local transform = get_transform(node)
    local nname = node.name and fix_invalid_name(node.name) or ("node" .. nodeidx)
    local policy = {
        "ant.general|name",
        "ant.scene|scene_object"
    }
    local data = {
        name = nname,
        scene = {srt=transform},
    }
    --add_animation(gltfscene, exports, nodeidx, policy, data)
    return create_entity {
        policy = policy,
        data = data,
        parent = parent,
    }
end

local function find_mesh_nodes(gltfscene, scenenodes, meshnodes)
    for _, nodeidx in ipairs(scenenodes) do
        local node = gltfscene.nodes[nodeidx+1]
        if node.children then
            find_mesh_nodes(gltfscene, node.children, meshnodes)
        end

        if node.mesh then
            meshnodes[#meshnodes+1] = nodeidx
        end
    end
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

    local meshnodes = {}
    find_mesh_nodes(gltfscene, scene.nodes, meshnodes)

    local C = {}
    local scenetree = exports.scenetree
    local function check_create_node_entity(nodeidx)
        local p_nodeidx = scenetree[nodeidx]
        local parent
        if p_nodeidx == nil then
            parent = rootid
        else
            parent = C[p_nodeidx]
            if parent == nil then
                parent = check_create_node_entity(p_nodeidx)
            end
        end

        local node = gltfscene.nodes[nodeidx+1]
        local e
        if node.mesh then
            e = create_mesh_node_entity(gltfscene, nodeidx, parent, exports)
        else
            e = create_node_entity(gltfscene, nodeidx, parent, exports)
        end

        C[nodeidx] = e
        return e
    end

    for _, nodeidx in ipairs(meshnodes) do
        check_create_node_entity(nodeidx)
    end
    utility.save_txt_file("./mesh.prefab", prefab)
end
