local utility           = require "model.utility"
local serialize         = import_package "ant.serialize"
local lfs               = require "bee.filesystem"
local material_compile  = require "material.compile"
local L                 = import_package "ant.render.core".layout
local depends           = require "depends"
local gltfutil          = require "model.glTF.util"

local function create_entity(t, prefabs)
    if t.parent then
        t.mount = t.parent
        t.data.scene = t.data.scene or {}
    end
    table.sort(t.policy)
    prefabs[#prefabs+1] = {
        policy = t.policy,
        data = t.data,
        mount = t.mount,
        tag = t.tag,
    }
    return #prefabs
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

local DEFAULT_MASKS<const> = "main_view|selectable|cast_shadow"

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

local check_update_material_info; do
    local function declname_shortnames(declname)
        local n = {}
        for dn in declname:gmatch "%w+" do
            n[#n+1] = dn:sub(1, 1)
        end
        table.sort(n)
        return table.concat(n, "")
    end

    local function build_cfg_name(basename, cfg)
        return ("%s_%s%s"):format(basename, cfg.pack_tangent_frame, declname_shortnames(cfg.binded_declname))
    end

    local function build_name(filename, cfg)
        local basename = lfs.path(filename):stem():string()
        return build_cfg_name(basename, cfg)
    end

    local build_varyings; do
        function build_varyings(cfg, mat)
            local varyings = L.varying_inputs(cfg.binded_declname)

            if cfg.pack_tangent_frame and varyings.a_tangent then
                assert(not varyings.a_normal, "Normal should pack to Tangent attirb")
                local v = {}
                for n in varyings.a_tangent:gmatch "%w+" do
                    v[#v+1] = n
                end
    
                varyings.a_tangent = {
                    type = v[1],
                    bind = v[2],
                    pack_from_quat = true,
                }
            end

            --varying
            local num_varying = 0
            local function gen_varying(a, v, n)
                assert(n > 1)
                for i=0, n-1 do
                    local aa = a .. i
                    if not varyings[aa] then
                        return i
                    end
                    local vv = v .. i
                    varyings[vv] = varyings[aa]
                end
            end

            local vtex_idx = gen_varying("a_texcoord", "v_texcoord", 8)
            num_varying = num_varying + vtex_idx
            num_varying = num_varying + gen_varying("a_color", "v_color", 4)

            if mat.fx.setting.lighting == "on" then
                varyings.v_posWS    = "vec3 TEXCOORD" .. vtex_idx
                varyings.v_tangent  = "vec3 TANGENT"
                varyings.v_normal   = "vec3 NORMAL"
                varyings.v_bitangent= "vec3 BITANGENT"

                num_varying = num_varying + 4
            end

            if num_varying > 16 then
                error(("Too many varying attribute:%d, max number is: 16"):format(num_varying))
            end
            return varyings
        end
    end


    local function build_material(material, cfg)
        local nm = duplicate_table(material)
        nm.fx.varyings = build_varyings(cfg, nm)
        return nm
    end
    function check_update_material_info(status, filename, material, cfg)
        local basename = lfs.path(filename):stem():string()
        local c = status.material_cache[basename]
        if c == nil then
            c = {}
            status.material_cache[basename] = c
        end

        local name = build_name(filename, cfg)

        local cc = c[name]
        if nil == cc then
            -- check next(c) to let the first material file use basename, because most materials with the same basic name have only one
            local fn = ("materials/%s.material"):format(next(c) and name or basename)
            local mi = build_material(material, cfg)
            cc = {
                filename = fn,
                material = mi,
            }

            c[name] = cc
            material_compile(status.tasks, status.post_tasks, status.depfiles, cc.material, status.input, status.output / cc.filename, status.setting)
        end
        return cc
    end
end

local function seri_material(status, filename, cfg)
    local material_names = status.material_names
    local stem = lfs.path(filename):stem():string()

    if filename:sub(1, 1) == "/" then
        material_names[stem] = stem
        return filename
    else
        local material = assert(status.material[filename])
        local info = check_update_material_info(status, filename, material, cfg)
        local newstem = lfs.path(info.filename):stem():string()
        material_names[newstem] = stem
        return info.filename
    end
end

local function GetJointsMap(model, primitives)
    local jointsMap = {}
    local accessorIndex = primitives.attributes["JOINTS_0"]
    if not accessorIndex then
        return jointsMap
    end
    local accessor = model.accessors[accessorIndex+1]
    local view = model.bufferViews[accessor.bufferView+1]
    local compcount = gltfutil.type_count_mapper[accessor.type]
    local compsize = gltfutil.comptype_size_mapper[accessor.componentType]
    assert(compsize == 1)
    assert(compcount == 4)
    local buf = model.buffers[view.buffer+1]
    for i = 0, accessor.count-1 do
        local buf_offset = (view.byteOffset or 0) + accessor.byteOffset + i * view.byteStride
        assert(buf_offset + 4 <= buf.byteLength)
        local v1, v2, v3, v4 = string.unpack("I1I1I1I1", buf.bin:sub(buf_offset + 1, buf_offset + 4))
        jointsMap[v1] = true
        jointsMap[v2] = true
        jointsMap[v3] = true
        jointsMap[v4] = true
    end
    return jointsMap
end

local function find_render_layer(state)
    if state.BLEND then
        return "translucent"
    end
end

local function create_mesh_node_entity(math3d, gltfscene, parentNodeIndex, nodeidx, parent, status, prefabs)
    local node = gltfscene.nodes[nodeidx+1]
    local srt = get_transform(math3d, node)
    local meshidx = node.mesh
    local mesh = gltfscene.meshes[meshidx+1]

    local function mesh_declname(em)
        local declname = em.declname
        if #declname == 2 then
            return ("%s|%s"):format(declname[1], declname[2])
        end

        return declname[1]
    end

    local entity
    for primidx, prim in ipairs(mesh.primitives) do
        local em        = status.mesh[meshidx+1][primidx]
        local mode      = prim.mode or 4
        assert(mode == 4, "Only 'TRIANGLES' primitive mode is supported")

        local materialfile = status.material_idx[prim.material+1] or error(("Invalid prim.material index:%d"):format(prim.material+1))
        local meshfile = em.meshbinfile or error(("not found meshfile in export data:%d, %d"):format(meshidx+1, primidx))

        status.material_cfg[meshfile] = {
            pack_tangent_frame      = em.pack_tangent_frame and "P" or "",
            binded_declname         = mesh_declname(em),
        }

        local materialcontent = status.material[materialfile] or error(("Invalid material file:%s, not found material content"):format(materialfile))
        local data = {
            mesh            = meshfile,
            material        = assert(materialfile, "Not found material file"),
            render_layer    = find_render_layer(materialcontent.state),
            visible_masks   = DEFAULT_MASKS,
            visible         = true,
        }

        local policy = {}

        if node.skin and status.animation then
            --local jointsMap = GetJointsMap(gltfscene, prim)
            policy[#policy+1] = "ant.render|skinrender"
            policy[#policy+1] = "ant.animation|skinning"
            data.scene = {}
            data.skinning = node.skin+1
        else
            policy[#policy+1] = "ant.render|render"
            data.scene    = {s=srt.s,r=srt.r,t=srt.t}
        end

        --mesh node's parent is bone node
        local parentNode = parentNodeIndex and gltfscene.nodes[parentNodeIndex+1]
        if status.skeleton and parentNode then
            local joint_index = status.skeleton:joint_index(parentNode.name)
            if joint_index and (joint_index ~= 1) then
                policy[#policy+1] = "ant.modifier|modifier"
                parent = 1
                data.modifier = { parentNode.name }
            end
        end

        entity = create_entity({
            policy = policy,
            data   = data,
            parent = parent,
            tag    = node.name and { node.name } or nil,
        }, prefabs)
    end
    return entity
end

local function create_node_entity(math3d, gltfscene, nodeidx, parent, status, prefabs)
    local node = gltfscene.nodes[nodeidx+1]
    local srt = get_transform(math3d, node)
    local policy = {
        "ant.scene|scene_object"
    }
    local data = {
        scene = {s=srt.s,r=srt.r,t=srt.t}
    }
    --add_animation(gltfscene, status, nodeidx, policy, data)
    return create_entity({
        policy = policy,
        data = data,
        parent = parent,
        tag    = node.name and { node.name } or nil,
    }, prefabs)
end

local function create_root_entity(status, prefabs)
    if not status.animation then
        return create_entity({
            policy = {
                "ant.scene|scene_object",
            },
            data = {
                scene = {},
            },
        }, prefabs)
    else
        return create_entity({
            policy = {
                "ant.animation|animation",
            },
            data = {
                scene = {},
                animation = "animations/animation.ozz",
            },
            tag = {"animation"},
        }, prefabs)
    end
end

local function has_mesh(model, nodeIndex, meshnodes)
    if meshnodes[nodeIndex] ~= nil then
        return meshnodes[nodeIndex]
    end
    local node = model.nodes[nodeIndex+1]
    if node.children then
        if node.mesh then
            for _, childIndex in ipairs(node.children) do
                has_mesh(model, childIndex, meshnodes)
            end
            meshnodes[nodeIndex] = true
            return true
        end
        local has = false
        for _, childIndex in ipairs(node.children) do
            local childHas = has_mesh(model, childIndex, meshnodes)
            has = has or childHas
        end
        meshnodes[nodeIndex] = has
        return has
    end
    local has = node.mesh ~= nil
    meshnodes[nodeIndex] = has
    return has
end

local function find_mesh_nodes(model, scene)
    local meshnodes = {}
    for _, nodeIndex in ipairs(scene.nodes) do
        has_mesh(model, nodeIndex, meshnodes)
    end
    return meshnodes
end

local function serialize_path(path)
    if path:sub(1,1) ~= "/" then
        return serialize.path(path)
    end
    return path
end

local function serialize_prefab(status, data)
    for _, v in ipairs(data) do
        local e = v.data
        if e then
            if e.material then
                e.material = serialize_path(seri_material(status, e.material, status.material_cfg[e.mesh]))
            end
            if e.mesh then
                e.mesh = serialize_path(e.mesh)
            end
            if e.animation and e.animation ~= true then
                e.animation = serialize_path(e.animation)
            end
        end
    end
    return data
end

local function compile_animation(status, skeleton, name, file)
    if not lfs.path(file):equal_extension ".anim" then
        return serialize_path(file)
    end
    local anim2ozz = require "model.anim2ozz"
    local vfs_fastio = require "vfs_fastio"
    local loc_fastio = require "fastio"
    local skecontent = skeleton:sub(1,1) == "/"
         and vfs_fastio.readall_f(status.setting, skeleton)
         or loc_fastio.readall_f((status.output / "animations" / skeleton):string())
    depends.add_vpath(status.depfiles, status.setting, file)
    anim2ozz(status.setting, skecontent, file, (status.output / "animations" / (name..".bin")):string())
    return serialize.path(name..".bin")
end

return function (status)
    local math3d = status.math3d
    local gltfscene = status.gltfscene
    local sceneidx = gltfscene.scene or 0
    local scene = gltfscene.scenes[sceneidx+1]

    status.prefab = {}
    status.di_prefab = {}
    status.material_names = {}

    local meshnodes = find_mesh_nodes(gltfscene, scene)
    local function build_prefabs(prefabs, suffix)
        local rootid = create_root_entity(status, prefabs)
        local function ImportNode(parent, nodes, parentNodeIndex)
            for _, nodeIndex in ipairs(nodes) do
                if meshnodes[nodeIndex] then
                    local node = gltfscene.nodes[nodeIndex+1]
                    local entity
                    if node.mesh then
                        entity = create_mesh_node_entity(math3d, gltfscene, parentNodeIndex, nodeIndex, parent, status, prefabs)
                    -- TODO: don't export bone node
                    -- else
                    --     entity = create_node_entity(math3d, gltfscene, nodeIndex, parent, status, prefabs)
                    end
                    if node.children then
                        ImportNode(entity or parent, node.children, nodeIndex)
                    end
                end
            end
        end
        ImportNode(rootid, scene.nodes)

        if suffix and (not status.animation) then
            if not status.animation then
                for _, e in ipairs(prefabs) do
                    if e and e.data.mesh then
                        e.policy[#e.policy+1] = "ant.render|draw_indirect"
                        e.data.draw_indirect = {
                            instance_buffer = {
                                flag    = "ra",
                                layout  = "t45NIf|t46NIf|t47NIf",
                                num     = 0,
                                size    = 50,
                                params  = {},
                            }
                        }
                    end
                end 
            end
            for _, patchs in pairs(status.patch) do
                for _, patch in ipairs(patchs) do
                    local v = patch.value
                    if type(v) == "table" and v.mount and v.prefab then
                        v.prefab = v.prefab:gsub("(%.[^%.]+)$", "_di%1")
                    end
                end
            end
        end

        utility.save_txt_file(status, "mesh.prefab", prefabs, function (data)
            return serialize_prefab(status, data)
        end, suffix)
    
    
        utility.save_txt_file(status, "translucent.prefab", prefabs, function (data)
            for _, v in ipairs(data) do
                local e = v.data
                if e then
                    if e.material then
                        e.material = serialize_path "/pkg/ant.resources/materials/translucent.material"
                    end
                end
            end
            return data
        end, suffix)
    end

    build_prefabs(status.prefab)
    build_prefabs(status.di_prefab, "di")

    if status.animation then
        utility.save_txt_file(status, "animations/animation.ozz", status.animation, function (t)
            if t.skeleton then
                if t.animations then
                    for name, file in pairs(t.animations) do
                        t.animations[name] = compile_animation(status, t.skeleton, name, file)
                    end
                end
                if t.skins then
                    for i, file in ipairs(t.skins) do
                        t.skins[i] = serialize_path(file)
                    end
                end
                t.skeleton = serialize_path(t.skeleton)
            end
            return t
        end)
    end


    utility.save_txt_file(status, "materials_names.ant", status.material_names, function (data) return data end)
end
