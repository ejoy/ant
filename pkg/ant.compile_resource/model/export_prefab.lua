local utility           = require "model.utility"
local serialize         = import_package "ant.serialize"
local lfs               = require "bee.filesystem"
local material_compile  = require "material.compile"
local L                 = import_package "ant.render.core".layout
local depends           = require "depends"
local gltfutil          = require "model.glTF.util"
local parallel_task     = require "parallel_task"
local build_animation   = require "model.build_animation"

local function create_entity(t, prefabs)
    if t.mount and next(t.mount) == nil then
        t.mount = nil
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



local check_refine_material; do
    local function declname_shortnames(declname)
        local n = {}
        for dn in declname:gmatch "%w+" do
            n[#n+1] = dn:sub(1, 1)
        end
        table.sort(n)
        return table.concat(n, "")
    end

    local function build_cfg_name(basename, cfg)
        return ("%s_%s%s%s"):format(basename, cfg.no_skinning, cfg.pack_tangent_frame, declname_shortnames(cfg.binded_declname))
    end

    local function build_name(filename, cfg)
        local basename = lfs.path(filename):stem():string()
        return build_cfg_name(basename, cfg)
    end

    local build_varyings; do
        local function check_tbn_varyings(varyings, cfg)
            if varyings.a_tangent then
                varyings.v_tangent  = "vec3 TANGENT"
                if cfg.pack_tangent_frame then
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
    
                    varyings.v_normal   = "vec3 NORMAL"
                    varyings.v_bitangent= "vec3 BITANGENT"
                end
            end

            if not varyings.v_normal and varyings.a_normal then 
                if not varyings.a_tangent or type(varyings.a_tangent) == "string" then
                    varyings.v_normal   = "vec3 NORMAL"
                end
            end

            if varyings.a_bitangent then
                varyings.v_bitangent= "vec3 BITANGENT"
            end

            local numvarying = 0
            if varyings.v_normal then
                numvarying = numvarying + 1
            end

            if varyings.v_tangent then
                numvarying = numvarying + 1
            end

            if varyings.v_bitangent then
                numvarying = numvarying + 1
            end

            return numvarying
        end

        function build_varyings(cfg, mat)
            local varyings = L.varying_inputs(cfg.binded_declname)

            local num_varying = check_tbn_varyings(varyings, cfg)

            --varying
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

    function check_refine_material(status, materialtemplate, cfg)
        local basename = lfs.path(materialtemplate.filename):stem():string()
        local c = status.material_cache[basename]

        local name = build_name(materialtemplate.filename, cfg)

        local template = c[name]
        if nil == template then
            -- check next(c) to let the first material file use basename, because most materials with the same basic name have only one
            local fn = ("materials/%s.material"):format(next(c) and name or basename)
            local mi = build_material(materialtemplate.content, cfg)
            if cfg.no_skinning then
                mi.fx.setting.no_skinning = true
                mi.fx.varyings.a_indices = nil
                mi.fx.varyings.a_weight = nil
            end
            template = {
                filename    = fn,
                content     = mi,
            }
            c[name] = template

            utility.apply_patch(status, fn, mi, function (n, mc)
                status.refine_materials[n] = mc
                if mc.fx.setting.no_skinning then
                    mc.fx.varyings.a_indices = nil
                    mc.fx.varyings.a_weight = nil
                end
            end)
        end

        return template
    end
end

local function refine_material(status, materialtemplate, cfg)
    if materialtemplate.filename:sub(1, 1) ~= "/" then
        return check_refine_material(status, materialtemplate, cfg)
    end

    return materialtemplate
end

local function update_material_names(status, mt, rm)
    local stem = lfs.path(rm.filename):stem():string()
    if not status.material_names[stem] then
        status.material_names[stem] = lfs.path(mt.filename):stem():string()
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

        local needskinning<const> = node.skin and status.animation
        local materialcfg = {
            pack_tangent_frame  = em.pack_tangent_frame and "P" or "",
            binded_declname     = mesh_declname(em),
        }
        if not needskinning then
            materialcfg.no_skinning = "NS"
        end
        local materialtemplate = status.material[prim.material+1] or error(("Invalid prim.material index:%d"):format(prim.material+1))
        local rmaterial = refine_material(status, materialtemplate, materialcfg)
        update_material_names(status, materialtemplate, rmaterial)

        local policy = {}
        local data = {
            mesh            = em.meshbinfile or error(("not found meshfile in export data:%d, %d"):format(meshidx+1, primidx)),
            material        = rmaterial.filename,
            render_layer    = find_render_layer(rmaterial.content.state),
            visible_masks   = DEFAULT_MASKS,
            visible         = true,
        }
        local mount = {
            ["/scene/parent"] = parent,
        }

        if needskinning then
            --local jointsMap = GetJointsMap(gltfscene, prim)
            policy[#policy+1] = "ant.render|skinrender"
            policy[#policy+1] = "ant.animation|skinning"
            data.scene = {}
            data.skinning = {
                skin = node.skin+1,
            }
            mount["/skinning/animation"] = status.animation_id
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
                mount["/scene/parent"] = 1
                data.modifier = { parentNode.name }
            end
        end

        entity = create_entity({
            policy = policy,
            data   = data,
            mount  = mount,
            tag    = node.name and { node.name } or nil,
        }, prefabs)
    end
    return entity
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

local function add_compile_material_task(status, materialfile)
    if status.material_tasks[materialfile] then
        return
    end

    status.material_tasks[materialfile] = true
    local materialcontent = assert(status.refine_materials[materialfile], materialfile)
    parallel_task.add(status.tasks, function ()
        material_compile(status.depfiles, materialcontent, status.input, status.output / materialfile, status.setting)
    end)
end

local function serialize_prefab(status, data)
    for _, v in ipairs(data) do
        local e = v.data
        if e then
            if e.material then
                add_compile_material_task(status, e.material)
                e.material = serialize_path(e.material)
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

local function fetch_scene(gltfscene)
    return gltfscene.scenes[(gltfscene.scene or 0)+1]
end

local function build_prefabs(status, prefabs, meshnodes, suffix)
    local math3d    = status.math3d
    local gltfscene = status.gltfscene
    local scene     = fetch_scene(gltfscene)
    local rootid    = create_entity({
        policy = {
            "ant.scene|scene_object",
        },
        data = {
            scene = {},
        },
    }, prefabs)
    if status.animation then
        status.animation_id = create_entity({
            policy = {
                "ant.animation|animation",
            },
            data = {
                animation = "animations/animation.ozz",
            },
            tag = { "animation" },
        }, prefabs)
    end
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
                            size    = 10,
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

local function init_material_data(status)
    status.material_names = {}
    status.material_cache = setmetatable({}, {__index=function (t, k) local tt = {}; t[k] = tt; return tt end})
    status.material_tasks = {}
    status.refine_materials = {}
end

local function init_prefab_export(status)
    status.prefab, status.di_prefab = {}, {}
    init_material_data(status)
end

return function (status)
    init_prefab_export(status)

    local gltfscene = status.gltfscene
    local scene     = fetch_scene(gltfscene)

    local meshnodes = find_mesh_nodes(gltfscene, scene)
    build_prefabs(status, status.prefab, meshnodes)
    build_prefabs(status, status.di_prefab, meshnodes, "di")

    if status.animation then
        build_animation(status)
    end
    utility.save_txt_file(status, "materials_names.ant", status.material_names, function (data) return data end)
end
