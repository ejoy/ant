local math3d = require "math3d"
local utility = require "editor.model.utility"
local serialize = import_package "ant.serialize"
local datalist = require "datalist"
local lfs = require "filesystem.local"
local fs = require "filesystem"
local compile = require "editor.compile"

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

local material_cache = {}

local function generate_material(mi, mode, hasskin)
    local sname = primitive_names[mode+1]
    if not sname then
        error(("not support primitate state, mode:%d"):format(mode))
    end

    local filename = mi.filename
    local function gen_key(fn, sn, skn)
        fn = fn:sub(1, 4) == "/pkg" and fn or utility.full_path(fn):string()
        return fn .. sn .. skn
    end

    local skn = hasskin and "_skin" or ""
    local key = gen_key(filename:string(), sname, skn)

    local m = material_cache[key]
    if m == nil then
        if sname == "" and skn == "" then
            m = mi
        else
            local basename = filename:stem():string()

            local nm = duplicate_table(mi.material)
            local s = nm.state
            if sname == "" then
                s.PT = nil
            else
                s.PT = sname
                basename = basename .. "_" .. sname
            end

            if hasskin then
                if nil == nm.fx.setting then
                    nm.fx.setting = {}
                end
                nm.fx.setting.GPU_SKINNING = 1
                basename = basename .. "_skin"
            end
            m = {
                filename = filename:parent_path() / (basename .. ".material"),
                material = nm
            }
        end

        material_cache[key] = m
    end

    return m
end

local function read_file(fn)
    local f<close> = fs.open(fn)
    return f:read "a"
end

local function read_material_file(filename)
    local mi = serialize.parse(filename, read_file(filename))
    if type(mi.state) == "string" then
        mi.state = serialize.parse(filename, read_file(fs.path(mi.state)))
    end
    return mi
end

local default_material_path<const> = lfs.path "/pkg/ant.resources/materials/pbr_default.material"
local default_material_info

local material_files = {}

local function save_material(output, exports, mi)
    local f = utility.full_path(mi.filename:string())
    if not material_files[f:string()] then
        lfs.remove_all(f)
        utility.save_txt_file(mi.filename:string(), mi.material)
        local outfolder = output / "materials" / "_tmp"
        compile.do_compile(output / mi.filename, outfolder, exports.depfiles)
        lfs.remove_all(f)
        lfs.rename(outfolder, output / mi.filename)

        material_files[f:string()] = true
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

local function has_skin(gltfscene, exports, nodeidx)
    local node = gltfscene.nodes[nodeidx+1]
    if node.skin and next(exports.animations) and exports.skeleton then
        if node.skin then
            return true
        end
    end
end

local function seri_material(output, exports, mode, materialidx, hasskin)
    local em = exports.material
    if em == nil or #em <= 0 then
        return
    end

    if materialidx then
        local mi = assert(exports.material[materialidx+1])
        local materialinfo = generate_material(mi, mode, hasskin)
        if materialinfo then
            save_material(output, exports, materialinfo)
            return materialinfo.filename
        end
    end

    if default_material_info == nil then
        default_material_info = {
            material = read_material_file(default_material_path),
            filename = default_material_path,
        }
    end

    local materialinfo = generate_material(default_material_info, mode)
    if materialinfo and materialinfo.filename ~= default_material_path then
        save_material(output, exports, materialinfo)
        return materialinfo.filename
    end

    return default_material_path
end

local function read_local_file(materialfile)
    local f <close> = lfs.open(materialfile)
    return f:read "a"
end

local function check_create_skin_material(materialfile)
    local n = materialfile:stem():string() .. "_skin"
    local newpath = materialfile:parent_path() / (n .. materialfile:extension())
    local fullnewpath = utility.full_path(newpath:string())
    if lfs.exists(fullnewpath) then
        return newpath
    end

    local lmf = lfs.path(utility.full_path(materialfile:string()))
    local m = datalist.parse(read_local_file(lmf))
    if nil == m.fx.setting then
        m.fx.setting = {}
    end

    m.fx.setting.GPU_SKINNING = 1
    utility.save_txt_file(newpath:string(), m)
    return newpath
end

local function create_mesh_node_entity(output, gltfscene, nodeidx, parent, exports)
    local node = gltfscene.nodes[nodeidx+1]
    local srt = get_transform(node)
    local meshidx = node.mesh
    local mesh = gltfscene.meshes[meshidx+1]

    local entity
    for primidx, prim in ipairs(mesh.primitives) do
        local meshname = mesh.name and fix_invalid_name(mesh.name) or ("mesh" .. meshidx)
        local needskin = has_skin(gltfscene, exports, nodeidx)
        local materialfile = seri_material(output, exports, prim.mode or 4, prim.material, needskin)
        if materialfile == nil then
            materialfile = fs.path "/pkg/ant.resources/materials/pbr_default.material"
            --error(("not found %s material %d"):format(meshname, prim.material or -1))
        end
        local meshfile = exports.mesh[meshidx+1][primidx]
        if meshfile == nil then
            error(("not found meshfile in export data:%d, %d"):format(meshidx+1, primidx))
        end

        local data = {
            mesh        = serialize.path(meshfile),
---@diagnostic disable-next-line: need-check-nil
            material    = serialize.path(materialfile:string()),
            name        = node.name or "",
            visible_state= DEFAULT_STATE,
        }

        local policy = {
            "ant.general|name",
        }

        if needskin then
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
            parent = (not needskin) and parent,
        }
    end
    return entity
end

local function create_node_entity(gltfscene, nodeidx, parent, exports)
    local node = gltfscene.nodes[nodeidx+1]
    local srt = get_transform(node)
    local nname = node.name and fix_invalid_name(node.name) or ("node" .. nodeidx)
    local policy = {
        "ant.general|name",
        "ant.scene|scene_object"
    }
    local data = {
        name = nname,
        scene = {s=srt.s,r=srt.r,t=srt.t}
    }
    --add_animation(gltfscene, exports, nodeidx, policy, data)
    return create_entity {
        policy = policy,
        data = data,
        parent = parent,
    }
end

local function create_skin_entity(exports, parent, withanim)
    if not exports.skeleton or #exports.skin < 1 then
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
    data.skeleton = serialize.path(exports.skeleton)
    data.meshskin = serialize.path(exports.skin[1])
    return create_entity {
        policy = policy,
        data = data,
        parent = parent,
    }
end

local function create_animation_entity(exports)
    local policy = {
        "ant.general|name",
        "ant.animation|animation",
    }
    local data = {
        name = "animation",
    }
    data.skeleton = serialize.path(exports.skeleton)
    data.animation = {}
    local anilst = {}
    for name, file in pairs(exports.animations) do
        local n = fix_invalid_name(name)
        anilst[#anilst+1] = n
        data.animation[n] = serialize.path(file)
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

return function(output, glbdata, exports, localpath)
    prefab = {}
    material_files = {}
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

    create_skin_entity(exports, rootid, true)

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
            e = create_mesh_node_entity(output, gltfscene, nodeidx, parent, exports)
        else
            e = create_node_entity(gltfscene, nodeidx, parent, exports)
        end

        C[nodeidx] = e
        return e
    end

    for _, nodeidx in ipairs(meshnodes) do
        check_create_node_entity(nodeidx)
    end
    if next(exports.animations) then
        create_animation_entity(exports)
        -- export animations
        local anilst = {}
        local animation = {}
        for name, file in pairs(exports.animations) do
            local n = fix_invalid_name(name)
            anilst[#anilst+1] = n
            animation[n] = serialize.path(file)
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
                    skeleton = serialize.path(exports.skeleton),
                    animation = animation,
                    animation_birth = anilst[1],
                    anim_ctrl = {},
                },
            }
        }
        utility.save_txt_file("./animation.prefab", anim_prefab)
    end
    utility.save_txt_file("./mesh.prefab", prefab)
end
