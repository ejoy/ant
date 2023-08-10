local utility = require "editor.model.utility"
local serialize = import_package "ant.serialize"
local lfs = require "bee.filesystem"
local fs = require "filesystem"
local material_compile = require "editor.material.compile"

local invalid_chars<const> = {
    '<', '>', ':', '/', '\\', '|', '?', '*', ' ', '\t', '\r', '%[', '%]', '%(', '%)'
}

local pattern_fmt<const> = ("[%s]"):format(table.concat(invalid_chars, ""))
local replace_char<const> = '_'

local function fix_invalid_name(name)
    return name:gsub(pattern_fmt, replace_char)
end

local prefab

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

local function get_transform(math3d, node)
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

local function duplicate_table(m)
    local t = {}
    for k, v in pairs(m) do
        if type(v) == "table" then
            t[k] = duplicate_table(v)
        else
            t[k] = v
        end
    end
    return t
end

local PRIMITIVE_MODES<const> = {
    "POINTS",
    "LINES",
    false, --LINELOOP, not support
    "LINESTRIP",
    "",         --TRIANGLES
    "TRISTRIP", --TRIANGLE_STRIP
    false, --TRIANGLE_FAN not support
}

local check_update_material_info, clean_material_cache;
do
    local CACHE
    function clean_material_cache() CACHE = {} end

    local function build_cfg_name(basename, cfg)
        local t = {}
        if cfg.with_color_attrib then
            t[#t+1] = "c"
        end
        if cfg.with_normal_attrib then
            t[#t+1] = "n"
        end
        if not cfg.with_tangent_attrib then
            t[#t+1] = "uT"
        end
        if cfg.hasskin then
            t[#t+1] = "s"
        end
        if not cfg.pack_tangent_frame then
            t[#t+1] = "up"
        end
        if cfg.modename ~= "" then
            t[#t+1] = cfg.modename
        end
        if #t == 0 then
            return basename
        end
        return ("%s_%s"):format(basename, table.concat(t))
    end

    local function material_info_need_change(name, mi)
        return name:match(mi.filename:stem():string())
    end

    local function build_name(mi, cfg)
        local basename = mi.filename:stem():string()
        return build_cfg_name(basename, cfg)
    end

    local function build_material(mi, name, cfg)
        if not material_info_need_change(name, mi) then
            return mi
        end

        local nm = duplicate_table(mi.material)
        assert(mi.filename:extension():string() == ".material")

        local nmi = {
            filename = mi.filename:parent_path() / (name .. ".material"),
            material = nm,
        }

        local function add_setting(n, v)
            if nil == nm.fx.setting then
                nm.fx.setting = {}
            end

            nm.fx.setting[n] = v
        end

        if cfg.modename ~= "" then
            mi.state.PT = cfg.modename
        end

        if cfg.with_color_attrib then
            add_setting("WITH_COLOR_ATTRIB", 1)
        end

        if cfg.with_normal_attrib then
            add_setting("WITH_NORMAL_ATTRIB", 1)
        end

        if cfg.with_tangent_attrib then
            add_setting("WITH_TANGENT_ATTRIB", 1)
        end

        if cfg.hasskin then
            add_setting("GPU_SKINNING", 1)
        end

        if not cfg.pack_tangent_frame then
            add_setting("PACK_TANGENT_TO_QUAT", 0)
        end
        return nmi
    end
    function check_update_material_info(mi, cfg)
        local name = build_name(mi, cfg)
        local c = CACHE[name]
        if c == nil then
            c = build_material(mi, name, cfg)
            CACHE[name] = c
        end
        return c
    end
end

local function read_file(fn)
    local f <close> = fs.open(fn)
    return f:read "a"
end

local function read_material_file(filename)
    local mi = serialize.parse(filename:string(), read_file(filename))
    if type(mi.state) == "string" then
        mi.state = serialize.parse(filename:string(), read_file(fs.path(mi.state)))
    end
    return mi
end

local DEFAULT_MATERIAL_PATH<const> = lfs.path "/pkg/ant.resources/materials/pbr_default.material"
local DEFAULT_MATERIAL_INFO

local function has_skin(gltfscene, status, nodeidx)
    local node = gltfscene.nodes[nodeidx+1]
    if node.skin and next(status.animations) and status.skeleton then
        if node.skin then
            return true
        end
    end
end

local function load_material_info(status, materialidx, cfg)
    local mi
    if materialidx then
        mi = assert(status.material[materialidx+1])
    end

    if DEFAULT_MATERIAL_INFO == nil then
        DEFAULT_MATERIAL_INFO = {
            material = read_material_file(DEFAULT_MATERIAL_PATH),
            filename = DEFAULT_MATERIAL_PATH,
        }
    end

    return check_update_material_info(mi or DEFAULT_MATERIAL_INFO, cfg)
end

local function seri_material(input, output, status, materialidx, cfg, setting)
    local em = status.material
    if em  and #em > 0 then
        local mi = load_material_info(status, materialidx, cfg)
        if mi and mi.filename ~= DEFAULT_MATERIAL_PATH then
            material_compile(status.tasks, status.depfiles, mi.material, input, output / mi.filename, setting, function (path)
                return fs.path(path):localpath()
            end)
            return mi.filename
        end
    end
    return DEFAULT_MATERIAL_PATH
end

local function create_mesh_node_entity(math3d, input, output, gltfscene, nodeidx, parent, status, setting)
    local node = gltfscene.nodes[nodeidx+1]
    local srt = get_transform(math3d, node)
    local meshidx = node.mesh
    local mesh = gltfscene.meshes[meshidx+1]

    local entity
    for primidx, prim in ipairs(mesh.primitives) do
        local em = status.mesh[meshidx+1][primidx]
        local hasskin = has_skin(gltfscene, status, nodeidx)
        local mode = prim.mode or 4
        local cfg = {
            hasskin                 = hasskin,                  --NOT define by default
            with_color_attrib       = em.with_color_attrib,     --NOT define by default
            pack_tangent_frame      = em.pack_tangent_frame,    --define by default, as 1
            with_normal_attrib      = em.with_normal_attrib,    --NOT define by default
            with_tangent_attrib     = em.with_tangent_attrib,   --define by default
            modename                = assert(PRIMITIVE_MODES[mode+1], "Invalid primitive mode"),
        }

        local materialfile = seri_material(input, output, status, prim.material, cfg, setting)
        local meshfile = em.meshbinfile
        if meshfile == nil then
            error(("not found meshfile in export data:%d, %d"):format(meshidx+1, primidx))
        end

        local data = {
            mesh        = meshfile,
---@diagnostic disable-next-line: need-check-nil
            material    = materialfile:string(),
            name        = node.name or "",
            visible_state= DEFAULT_STATE,
        }

        local policy = {
            "ant.general|name",
        }

        if hasskin then
            policy[#policy+1] = "ant.render|skinrender"
            data.skinning = true
        else
            policy[#policy+1] = "ant.render|render"
            data.scene    = {s=srt.s,r=srt.r,t=srt.t}
        end

        --TODO: need a mesh node to reference all mesh.primitives, we assume primitives only have one right now
        entity = create_entity {
            policy = policy,
            data = data,
            parent = (not hasskin) and parent,
        }
    end
    return entity
end

local function create_node_entity(math3d, gltfscene, nodeidx, parent, status)
    local node = gltfscene.nodes[nodeidx+1]
    local srt = get_transform(math3d, node)
    local nname = node.name and fix_invalid_name(node.name) or ("node" .. nodeidx)
    local policy = {
        "ant.general|name",
        "ant.scene|scene_object"
    }
    local data = {
        name = nname,
        scene = {s=srt.s,r=srt.r,t=srt.t}
    }
    --add_animation(gltfscene, status, nodeidx, policy, data)
    return create_entity {
        policy = policy,
        data = data,
        parent = parent,
    }
end

local function create_skin_entity(status, parent, withanim)
    if not status.skeleton or #status.skin < 1 then
        return
    end
    local policy = {
        "ant.general|name",
        "ant.scene|scene_object",
        "ant.animation|meshskin",
    }
    local data = {
        name = "meshskin",
        skinning = true,
        scene = {},
    }
    data.skeleton = status.skeleton
    data.meshskin = status.skin[1]
    return create_entity {
        policy = policy,
        data = data,
        parent = parent,
    }
end

local function create_animation_entity(status)
    local policy = {
        "ant.general|name",
        "ant.animation|animation",
    }
    local data = {
        name = "animation",
    }
    data.skeleton = status.skeleton
    data.animation = {}
    local anilst = {}
    for name, file in pairs(status.animations) do
        local n = fix_invalid_name(name)
        anilst[#anilst+1] = n
        data.animation[n] = file
    end
    table.sort(anilst)
    data.animation_birth = anilst[1] or ""
    data.anim_ctrl = {}
    create_entity {
        policy = policy,
        data = data,
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

local function cleanup()
    prefab = {}
    clean_material_cache()
end

local function serialize_path(path)
    if path:sub(1,1) ~= "/" then
        return serialize.path(path)
    end
    return path
end

local function serialize_prefab(data)
    for _, v in ipairs(data) do
        local e = v.data
        if e.animation then
            for name, file in pairs(e.animation) do
                e.animation[name] = serialize_path(file)
            end
        end
        if e.mesh then
            e.mesh = serialize_path(e.mesh)
        end
        if e.material then
            e.material = serialize_path(e.material)
        end
        if e.skeleton then
            e.skeleton = serialize_path(e.skeleton)
        end
        if e.meshskin then
            e.meshskin = serialize_path(e.meshskin)
        end
    end
    return data
end

return function (status)
    local input = status.input
    local output = status.output
    local glbdata = status.glbdata
    local setting = status.setting
    local math3d = status.math3d

    cleanup()
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
            scene = {},
        },
    }

    local meshnodes = {}
    find_mesh_nodes(gltfscene, scene.nodes, meshnodes)

    create_skin_entity(status, rootid, true)

    local C = {}
    local scenetree = status.scenetree
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
            e = create_mesh_node_entity(math3d, input, output, gltfscene, nodeidx, parent, status, setting)
        else
            e = create_node_entity(math3d, gltfscene, nodeidx, parent, status)
        end

        C[nodeidx] = e
        return e
    end

    for _, nodeidx in ipairs(meshnodes) do
        check_create_node_entity(nodeidx)
    end
    if next(status.animations) then
        create_animation_entity(status)
        -- export animations
        local anilst = {}
        local animation = {}
        for name, file in pairs(status.animations) do
            local n = fix_invalid_name(name)
            anilst[#anilst+1] = n
            animation[n] = file
        end
        table.sort(anilst)
        local anim_prefab = {
            {
                policy = {
                    "ant.general|name",
                    "ant.animation|animation",
                },
                data = {
                    name = "animation",
                    skeleton = status.skeleton,
                    animation = animation,
                    animation_birth = anilst[1],
                    anim_ctrl = {},
                },
            }
        }
        utility.save_txt_file(status, "animation.prefab", anim_prefab, serialize_prefab)
    end
    utility.save_txt_file(status, "mesh.prefab", prefab, serialize_prefab)
end
