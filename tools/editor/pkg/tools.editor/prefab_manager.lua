local ecs = ...
local world = ecs.world
local w = world.w
local ImGui         = import_package "ant.imgui"
local assetmgr      = import_package "ant.asset"
local serialize     = import_package "ant.serialize"
local mathpkg       = import_package "ant.math"
local aio           = import_package "ant.io"
local fastio        = require "fastio"
local mc            = mathpkg.constant
local iom           = ecs.require "ant.objcontroller|obj_motion"
local irq           = ecs.require "ant.render|render_system.renderqueue"
local stringify     = import_package "ant.serialize".stringify
local ilight        = ecs.require "ant.render|light.light"
local imodifier     = ecs.require "ant.modifier|modifier"
local camera_mgr    = ecs.require "camera.camera_manager"
local light_gizmo   = ecs.require "gizmo.light"
local gizmo         = ecs.require "gizmo.gizmo"
local editor_setting = require "editor_setting"
local math3d 		= require "math3d"
local fs            = require "filesystem"
local lfs           = require "bee.filesystem"
local hierarchy     = require "hierarchy_edit"
local widget_utils  = require "widget.utils"
local gd            = require "common.global_data"
local utils         = require "common.utils"
local iterrain      = ecs.require "ant.landform|plane_terrain"
local layoutmgr     = import_package "ant.render".layoutmgr
local bgfx          = require "bgfx"
local TERRAIN_MATERIAL <const> = "/pkg/vaststars.resources/materials/terrain/plane_terrain.material"
local BORDER_MATERIAL <const> = "/pkg/vaststars.resources/materials/terrain/border.material"
local anim_view
local m = {
    entities = {}
}

local lightidx = 0
local function gen_light_id() lightidx = lightidx + 1 return lightidx end

local geometricidx = 0
local function gen_geometry_id() geometricidx = geometricidx + 1 return geometricidx end

local function create_light_billboard(light_eid, lighttype)
    local vbdata = {
        -1, -1, 0, 0, 1,
        -1,  1, 0, 0, 0,
         1, -1, 0, 1, 1,
         1,  1, 0, 1, 0,
    }
    local layout = layoutmgr.get "p3|t2"
    return world:create_entity{
        policy = {
            "ant.render|simplerender",
            "ant.render|billboard"
        },
        data = {
            billboard = true,
            render_layer = "translucent",
            scene = {
                parent = light_eid
            },
            visible_state = "main_view",
            material = "/pkg/tools.editor/resource/materials/billboard_"..lighttype..".material",
            simplemesh = {
                vb = {
                    start = 0,
                    num = 4,
                    handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("fffff", vbdata), layout.handle)
                },
            }
        }
    }
end

local geom_mesh_file = {
    ["cube"] = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
    ["cone"] = "/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/Cone_P1.meshbin",
    ["cylinder"] = "/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/Cylinder_P1.meshbin",
    ["sphere"] = "/pkg/ant.resources.binary/meshes/base/sphere.glb|meshes/Sphere_P1.meshbin",
    ["torus"] = "/pkg/ant.resources.binary/meshes/base/torus.glb|meshes/Torus_P1.meshbin",
    ["plane"] = "/pkg/ant.resources.binary/meshes/base/plane.glb|meshes/Plane_P1.meshbin"
}

local slot_id = 1
function m:create_slot()
    local auto_name = "slot" .. slot_id
    slot_id = slot_id + 1
    local parent_eid = gizmo.target_eid or (self.scene and self.scene or self.root)
    local template = {
        policy = {
            "ant.animation|slot"
        },
        data = {
            scene = { parent = parent_eid },
            slot = {
                joint_name = "None",
                follow_flag = 1,
            },
        },
        tag = {
            auto_name
        }
    }
    local tpl = utils.deep_copy(template)
    tpl.data.on_ready = function (e) hierarchy:update_slot_list(world) end
    self:add_entity(world:create_entity(tpl), parent_eid, template)
end

local function create_simple_entity(name, parent)
    local template = {
		policy = {
            "ant.scene|scene_object",
		},
		data = {
            scene = {parent = parent},
		},
        tag = {
            name
        }
    }
    return world:create_entity(utils.deep_copy(template)), template
end

function m:add_entity(new_entity, parent, tpl, filename)
    self.entities[#self.entities+1] = new_entity
    if self.scene ~= new_entity then
        self.prefab_template[#self.prefab_template + 1] = tpl
        if self.glb_filename then
            tpl.index = #self.prefab_template
            tpl.filename = filename
        end
        local embed
        if filename then
            embed = {
                index = #self.prefab_template + 1,
                prefab = filename
            }
            self.prefab_template[#self.prefab_template + 1] = embed
        end
        self:pacth_add(tpl, embed)
    end
    hierarchy:add(new_entity, {template = tpl, filename = filename, editor = filename and false or nil, is_patch = true}, parent)
end

local function create_default_light(type, parent)
    local light, tpl = ilight.create {
        srt = {t = {0, 5, 0}, r = type == "directional" and {math.rad(130), 0, 0} or nil, parent = parent},
        name            = type .. gen_light_id(),
        type            = type,
        color           = {1, 1, 1, 1},
        make_shadow     = false,
        intensity       = 130000,--ilight.default_intensity(lt),
        intensity_unit  = ilight.default_intensity_unit(type),
        range           = 10,
        motion_type     = "dynamic",
        inner_radian    = math.rad(10),
        outter_radian   = math.rad(30)
    }
    create_light_billboard(light, type)
    return light, utils.deep_copy(tpl)
end

function m:clear_light()
    if not self.default_light then
        return
    end
    local all_entitys = self.default_light.tag["*"]
    for _, e in ipairs(all_entitys) do
        w:remove(e)
    end
    self.default_light = nil
end
function m:update_default_light(enable)
    self:clear_light()
    if enable then
        local filename = editor_setting.setting.light
        if not filename or not fs.exists(fs.path(filename)) then
            filename = "/pkg/tools.editor/resource/light.prefab"
        end
        self.light_prefab = filename
        if not self.default_light then
            self.default_light = world:create_instance {
                prefab = self.light_prefab
            }
        end
    end
end

function m:show_ground(enable)
    if not enable then
        w:remove(self.plane)
        self.plane = nil
    else
        self:create_ground()
    end
end

function m:show_terrain(enable)
    if not enable then
        iterrain.clear_plane_terrain()
    else
        iterrain.create_plane_terrain({[0] = {{x = -500, y = -500, type = "terrain"}}}, "opacity", 1000, TERRAIN_MATERIAL)
    end
end
function m:clone(eid)
    local srctpl = hierarchy:get_node_info(eid)
    if srctpl.filename then
        return
    end
    local dsttpl = utils.deep_copy(srctpl.template)
    local tmp = utils.deep_copy(dsttpl)
    local e <close> = world:entity(eid, "scene?in")
    if not e.scene then
        print("can not clone noscene node.")
        return
    end
    local name = (tmp.tag and tmp.tag[1] or "") .. "_copy"
    tmp.tag = { name }
    dsttpl.tag = { name }
    local pid = e.scene.parent > 0 and e.scene.parent or self.root
    tmp.data.scene.parent = pid
    if e.scene.slot then
        tmp.data.on_ready = function (obj) hierarchy:update_slot_list(world) end
    end
    local new_entity = world:create_entity(tmp)
    self:add_entity(new_entity, pid, dsttpl)
    world:pub {"EntityEvent", "tag", new_entity, {}, { name }}
end

function m:create(what, config)
    if not self.root then
        self:reset_prefab()
    end
    if what == "slot" then
        self:create_slot()
    elseif what == "camera" then
        local new_camera, template = camera_mgr.create_camera()
        hierarchy:add(new_camera, {template = template}, self.root)
        self.entities[#self.entities+1] = new_camera
    elseif what == "empty" then
        local parent = gizmo.target_eid or (self.scene and self.scene or self.root)
        local new_entity, temp = create_simple_entity("empty" .. gen_geometry_id(), parent)
        self:add_entity(new_entity, parent, temp)
    elseif what == "geometry" then
        if config.type == "cube" or config.type == "cone" or config.type == "cylinder"
            or config.type == "sphere" or config.type == "torus" or config.type == "plane" then
            local offsety = 1.0
            if config.type == "torus" then
                offsety = 0.25
            elseif config.type == "plane" then
                offsety = 0.001
            end
            local parent_eid = config.parent or gizmo.target_eid or (self.scene and self.scene or self.root)
            local template = {
                policy = {
                    "ant.render|render",
                },
                data = {
                    scene = {t = {0, offsety , 0}},
                    visible_state = "main_view|selectable",
                    material = "/pkg/ant.resources/materials/pbr_default.material",
                    mesh = geom_mesh_file[config.type],
                },
                tag = { config.type .. gen_geometry_id() }
            }
            local tmp = utils.deep_copy(template)
            tmp.data.scene.parent = parent_eid
            local new_entity = world:create_entity(tmp)
            self:add_entity(new_entity, parent_eid, template)
            return new_entity
        end
    elseif what == "light" then
        if config.type == "directional" or config.type == "point" or config.type == "spot" then
            local newlight, tpl = create_default_light(config.type, self.root)
            self:add_entity(newlight, self.root, tpl)
            light_gizmo.init()
        end
    elseif what == "timeline" then
        local template = {
            policy = {
                "ant.timeline|timeline",
            },
            data = {
                timeline = {
                    loop = false,
                    duration = 3,
                    key_event = {}
                },
            },
            tag = { "timeline" }
        }
        local tmp = utils.deep_copy(template)
        tmp.data.on_ready = function (e)
            w:extend(e, "timeline:in")
            e.timeline.eid_map = self.current_prefab and self.current_prefab.tag or {}
        end
        local new_entity = world:create_entity(tmp)
        self:add_entity(new_entity, nil, template)
    end
end

local function set_select_adapter(entity_set, mount_root)
    for _, e in ipairs(entity_set) do
        hierarchy:add_select_adapter(e, mount_root)
    end
end

function m:on_prefab_ready(prefab)
    local entitys = prefab.tag["*"]
    local function find_e(entitys, id)
        for _, eid in ipairs(entitys) do
            local e <close> = world:entity(eid, "eid:in")
            if e.eid == id then
                return eid
            end
        end
    end

    local function sub_tree(eid, idx)
        local st = {}
        local st_set = {}
        local e <close> = world:entity(eid, "eid:in")
        st_set[e.eid] = true
        for i = idx, #entitys do
            local entity <close> = world:entity(entitys[i], "scene?in eid:in")
            if entity.scene and st_set[entity.scene.parent] == nil then
                break
            end
            st_set[entity.eid] = true
            st[#st + 1] = entitys[i]
        end
        return st
    end

    local node_map = {}
    if self.glb_filename then
        for idx, value in ipairs(self.prefab_template) do
            value.index = idx
        end
    end
    local j = 1
    local last_tpl
    local anim_eid
    local tag_list = {}
    for i, pt in ipairs(self.prefab_template) do
        local eid = entitys[j]
        local e <close> = world:entity(eid, "scene?in light?in")
        local scene = e.scene
        local parent = scene and find_e(entitys, scene.parent)
        if pt.prefab then
            last_tpl.filename = pt.prefab
            local children = sub_tree(parent, j)
            j = j + #children
            local target_node = node_map[parent]
            target_node.children = children
            target_node.filename = pt.prefab
            target_node.editor = pt.editor or false
        else
            self.entities[#self.entities + 1] = eid
            local name = pt.tag and pt.tag[1]
            if pt.data.animation then
                anim_eid = eid
            end
            if not name then
                if i == 1 then
                    name = "Scene"
                else
                    name = pt.data.animation and "animation" or (pt.data.mesh and tostring(fs.path(pt.data.mesh):stem()) or (pt.data.meshskin and tostring(fs.path(pt.data.meshskin):stem()) or ""))
                end
            end
            tag_list[#tag_list + 1] = {name, eid}
            node_map[eid] = {template = pt, parent = parent, name = name, scene_root = (i == 1), is_patch = (i >= self.patch_start_index)}
            j = j + 1
        end
        last_tpl = pt
        if e.light then
            create_light_billboard(eid, e.light.type)
            light_gizmo.bind(eid)
            light_gizmo.show(false)
        end
    end
    self.scene = self.entities[1]
    local function add_to_hierarchy(eid)
        local node = node_map[eid]
        if node.parent and not hierarchy:get_node(node.parent) then
            add_to_hierarchy(node.parent)
        end
        local tp = {template = node.template, name = node.name, is_patch = node.is_patch, scene_root = node.scene_root}
        local children = node.children
        if children then
            set_select_adapter(children, eid)
            tp.filename = node.filename
            tp.editor = node.editor
        end
        hierarchy:add(eid, tp, node.parent or self.root)
    end

    for _, eid in ipairs(self.entities) do
        add_to_hierarchy(eid)
    end

    local srt = self.prefab_template[1].data.scene
    if srt then
        self.root_mat = math3d.ref(math3d.matrix(srt))
    end

    for _, v in ipairs(tag_list) do
        local tpl = hierarchy:get_node_info(v[2]).template
        if not tpl.tag then
            tpl.tag = {v[1]}
            self:on_patch_tag(v[2], nil, tpl.tag, true)
        end
    end
    self:update_tag_list()
    anim_view.on_prefab_load(anim_eid)
end

local prefabe_name_ui = {text = ""}
local prefab_list = {}
local patch_template
local faicons   = require "common.fa_icons"
local function reset_open_context()
    gd.glb_filename = nil
    gd.is_opening = false
    prefab_list = {}
    prefabe_name_ui = {text = ""}
end

local function get_prefabs_and_patch_template(glbfilename)
    local localPatchfile = lfs.path(glbfilename):string() .. ".patch"
    local patch_tpl = lfs.exists(lfs.path(localPatchfile)) and serialize.parse(localPatchfile, fastio.readall_s(localPatchfile)) or {}
    local prefab_set = {}
    for _, patch in ipairs(patch_tpl) do
        local k = (patch.file ~= "mesh.prefab") and patch.file or ((patch.op == "copyfile") and patch.path or nil)
        if k and string.sub(k, -7) == ".prefab" then
            prefab_set[k] = true
        end
    end
    local prefabs = {"mesh.prefab"}
    for key, _ in pairs(prefab_set) do
        prefabs[#prefabs + 1] = key
    end
    return prefabs, patch_tpl
end

function m:choose_prefab()
    if not gd.glb_filename then
        return
    end
    if #prefab_list < 1 then
        prefab_list, patch_template = get_prefabs_and_patch_template(gd.glb_filename)
    end
    local title = "Choose prefab"
    if not ImGui.IsPopupOpen(title) then
        ImGui.OpenPopup(title)
    end
    local change, opened = ImGui.BeginPopupModal(title, true, ImGui.Flags.Window{"AlwaysAutoResize"})
    if change then
        if gd.is_opening then

            ImGui.Text("Create new or open existing prefab.")
            ImGui.Text("prefab name:  ")
            ImGui.SameLine()
            if ImGui.InputText("##PrefabName", prefabe_name_ui) then
            end
            ImGui.SameLine()
            if ImGui.Button(faicons.ICON_FA_FOLDER_PLUS.." Create") then
                local name = tostring(prefabe_name_ui.text)
                if #name > 0 then
                    local existing = false
                    for _, value in ipairs(prefab_list) do
                        if value == name..".prefab" then
                            existing = true
                            break
                        end
                    end
                    if not existing then
                        prefab_list[#prefab_list + 1] = name..".prefab"
                        prefabe_name_ui.text = ""
                        local insert_index = 1
                        for index, value in ipairs(patch_template) do
                            insert_index = index
                            if value.file ~= "mesh.prefab" or value.op == "add" then
                                break
                            end
                        end
                        table.insert(patch_template, insert_index, {
                            file = "mesh.prefab",
                            op = "copyfile",
                            path = prefab_list[#prefab_list]
                        })
                        utils.write_file(gd.glb_filename..".patch", stringify(patch_template))
                    end
                end
            end
        else
            ImGui.Text("Choose a prefab to continue.")
        end
        ImGui.Separator()
        for _, prefab in ipairs(prefab_list) do
            if ImGui.Selectable(prefab, false, ImGui.Flags.Selectable {"AllowDoubleClick"}) then
                if gd.is_opening then
                    self:open(gd.glb_filename.."|".. prefab, prefab, patch_template)
                else
                    self:add_prefab(gd.glb_filename.."|"..prefab)
                end
                reset_open_context()
            end
        end
        ImGui.Separator()
        if ImGui.Button(faicons.ICON_FA_BAN.." Quit") then
            reset_open_context()
            ImGui.CloseCurrentPopup()
        end
        ImGui.EndPopup()
    end
end

local cr = import_package "ant.compile_resource"
local vfs = require "vfs"
local memfs = import_package "ant.vfs".memory

local function mount_dir(vroot, lpath, lroot)
    for path in lfs.pairs(lfs.path(lpath)) do
        if path:filename():string():sub(1,1) == "." then
            goto continue
        end
        if lfs.is_directory(path) then
            mount_dir(vroot, path, lroot)
        else
            local vp = vroot:string() .. "/" .. lfs.relative(path, lroot):string()
            memfs.update(vp, path:string())
        end
        ::continue::
    end
end

local function compile_glb(vpath, lpath)
    local config = cr.init_setting(vfs, "windows-direct3d11")
    local current_compile_path = cr.compile_file(config, vpath:string(), lpath:string())
    mount_dir(vpath, current_compile_path, current_compile_path)
    return current_compile_path
end

local function cook_prefab(prefab_filename)
    local pl = utils.split_ant_path(prefab_filename)
    if not pl[2] then
        return
    end
    local compile_path = compile_glb(lfs.path(pl[1]), lfs.path(gd.project_root:string()..pl[1]))
    prefab_filename = prefab_filename:gsub("|", "/")
    local prefab_template = serialize.parse(prefab_filename, aio.readall(prefab_filename))
    for _, tpl in ipairs(prefab_template) do
        if tpl.prefab then
            cook_prefab(tpl.prefab)
        end
    end
    return compile_path
end

function m:open(filename, prefab_name, patch_tpl)
    self:reset_prefab(true)
    self.prefab_filename = filename
    local isglb = false
    if filename:match('.glb|') or filename:match('.gltf|') then
        isglb = true
    end
    local path_list = isglb and utils.split_ant_path(filename) or {}
    local virtual_prefab_path = (lfs.path('/') / lfs.relative((#path_list > 1) and path_list[1] or filename, gd.project_root)):string()
    if #path_list > 1 then
        self.glb_filename = path_list[1]
        self.prefab_name = path_list[2]
        gd.virtual_prefab_path = virtual_prefab_path
        gd.current_compile_path = cook_prefab(virtual_prefab_path .. "|".. self.prefab_name)
        virtual_prefab_path = virtual_prefab_path .. "/" .. self.prefab_name
        self.prefab_template = serialize.parse(virtual_prefab_path, aio.readall(virtual_prefab_path))

        self.origin_patch_template = patch_tpl or {}
        self.patch_template = {}
        self.tag_patch = {}

        local anim_file = "animations/" .. self.prefab_name:sub(1, -8) .. ".ozz"
        local anim_patch = {}
        for _, patch in ipairs(self.origin_patch_template) do
            if patch.path == "hitch.prefab" then
                self.save_hitch = true
            elseif patch.file == self.prefab_name then
                self.patch_template[#self.patch_template + 1] = patch
            end
            if patch.file == "animations/animation.ozz" and patch.path == anim_file then
                anim_patch[#anim_patch + 1] = patch
            elseif patch.file == anim_file then
                anim_patch[#anim_patch + 1] = patch
            end
        end
        self.anim_file = anim_file
        self.anim_patch = anim_patch

        local node_idx = 0
        for _, patch in ipairs(self.patch_template) do
            if patch.op == "add" and patch.path == "/-" then
                node_idx = node_idx + 1
            end
        end
        self.patch_start_index = #self.prefab_template - node_idx + 1
    else
        self.prefab_template = serialize.parse(filename, fastio.readall_s(filename))
    end

    self.current_prefab = world:create_instance {
        prefab = virtual_prefab_path,
        on_ready = function(instance)
            self:on_prefab_ready(instance)
            hierarchy:update_slot_list(world)
            world:pub {"LookAtTarget", self.entities[1]}
        end
    }
    editor_setting.add_recent_file(filename)
    editor_setting.save()
    world:pub {"WindowTitle", virtual_prefab_path}
end

local function remove_entity_self(eid)
    local e <close> = world:entity(eid, "light?in")
    if e.light then
        light_gizmo.on_remove_light(eid)
    end
    local adaptee = hierarchy:get_select_adaptee(eid)
    if #adaptee > 0 then
        -- TODO: for camera, remove this for
        for i = #adaptee, 1, -1 do
            hierarchy:del(adaptee[i])
        end
        for _, id in ipairs(adaptee) do
            w:remove(id)
        end
        hierarchy:clear_adapter(eid)
    end
    hierarchy:del(eid)
    w:remove(eid)
end

function m:create_ground()
    if not self.plane then
        local imaterial = ecs.require "ant.asset|material"
        self.plane = world:create_entity {
            policy = {
                "ant.render|render",
            },
            data = {
                scene = {s = {200, 1, 200}},
                mesh  = "/pkg/tools.editor/resource/plane.glb|meshes/Plane_P1.meshbin",
                material    = "/pkg/tools.editor/resource/materials/texture_plane.material",
                render_layer = "background",
                visible_state= "main_view",
                on_ready = function (e)
                    imaterial.set_property(e, "u_uvmotion", math3d.vector{0, 0, 100, 100})
                end
            },
            tag = { "ground" }
        }
    end
end

function m:reset_prefab(noscene)
    for _, eid in ipairs(self.entities) do
        remove_entity_self(eid)
    end
    imodifier.set_target(imodifier.highlight, nil)
    light_gizmo.clear()
    hierarchy:clear()
    anim_view.clear()
    self.root = create_simple_entity("root")
    self.entities = {}
    world:pub {"WindowTitle", ""}
    world:pub {"ResetEditor", ""}
    world:pub {"UpdateAABB"}
    hierarchy:set_root(self.root)
    if self.prefab_filename then
        world:remove_template(self.prefab_filename)
    end
    gizmo:set_target()
    self:create_ground()
    self.materials_names = nil
    self.image_patch = {}
    self.patch_copy_material = {}
    self.prefab_template = {}
    self.patch_template = {}
    self.tag_patch = {}
    self.prefab_filename = nil
    self.glb_filename = nil
    self.scene = nil
    self.save_hitch = false
    self.patch_start_index = 0
    self.current_prefab = nil
    if not noscene then
        local parent = self.root
        local new_entity, temp = create_simple_entity("Scene", parent)
        self.scene = new_entity
        self:add_entity(new_entity, parent, temp)
    end
    if not self.main_camera then
        self.main_camera = irq.camera "main_queue"
    end
    local mq_camera = irq.camera "main_queue"
    if mq_camera ~= self.main_camera then
        irq.set_camera_from_queuename("main_queue", self.main_camera)
        irq.set_visible("second_view", false)
    end
end

function m:reload()
    local filename = self.prefab_filename
    if filename == 'nil' then
        self:save((gd.project_root / "resource/__temp__.prefab"):string())
    else
        local _, origin_patch_template = get_prefabs_and_patch_template(self.glb_filename)
        self:open(filename, self.prefab_name, origin_patch_template)
    end
end
local global_data       = require "common.global_data"
local access            = global_data.repo_access

function m:add_effect(filename)
    for path in lfs.pairs(lfs.path(filename):parent_path()) do
        local vpath = (lfs.path('/') / lfs.relative(path, gd.project_root)):string()
        memfs.update(vpath, path:string())
    end
    local virtual_path = (lfs.path('/') / lfs.relative(filename, gd.project_root)):string()
    if not self.root then
        self:reset_prefab()
    end
    local parent = gizmo.target_eid or (self.scene and self.scene or self.root)
    local name = fs.path(virtual_path):stem():string()
    local template = {
		policy = {
            "ant.scene|scene_object",
            "ant.efk|efk",
		},
		data = {
            scene = {parent = parent},
            efk = {
                path = virtual_path,
                speed = 1.0,
            },
            visible_state = "main_queue"
		},
        tag = {
            name
        }
    }
    local tpl = utils.deep_copy(template)
    local efk_eid = world:create_entity(tpl)
    if self.current_prefab then
        self.current_prefab.tag[name] = {efk_eid}
    end
    self:add_entity(efk_eid, parent, template)
end

function m:add_prefab(path)
    if not self.root then
        self:reset_prefab()
    end
    local path_list = utils.split_ant_path(path)
    local virtual_path = (lfs.path('/') / lfs.relative((#path_list > 1) and path_list[1] or path, gd.project_root)):string()
    if #path_list > 1 then
        virtual_path = virtual_path .. "|".. path_list[2]
        cook_prefab(virtual_path)
    end
    local parent = gizmo.target_eid or (self.scene and self.scene or self.root)
    local v_root, temp = create_simple_entity(tostring(fs.path(path):stem()), parent)
    world:create_instance {
        prefab = virtual_path,
        parent = v_root,
        on_ready = function(inst)
            local children = inst.tag["*"]
            if #children > 0 then
                set_select_adapter(children, v_root)
                if #children == 1 then
                    local child = children[1]
                    local e <close> = world:entity(child, "camera?in")
                    if e.camera then
                        local tpl = serialize.parse(virtual_path, aio.readall(virtual_path))
                        hierarchy:add(child, {template = tpl[1], editor = true, temporary = true}, v_root)
                    end
                end
            end
        end
    }
    self:add_entity(v_root, parent, temp, virtual_path)
end

function m:get_hitch_content()
    local content = {
        {
            policy = {
                "ant.render|hitch_object",
            },
            data = {
                scene = {},
                hitch = {
                    group = 0,
                },
                visible_state = "main_view|cast_shadow|selectable",
            },
            tag = {
                "hitch"
            }
        }
    }
    for _, tpl in ipairs(self.origin_patch_template) do
        if tpl.op == "add" and (type(tpl.value) == "table")
            and tpl.value.policy
            and #tpl.value.policy == 1
            and tpl.value.policy[1] == "ant.scene|scene_object"
            and (tpl.file == "mesh.prefab") then
            -- only one hitch file per glb file
            content[#content + 1] = tpl.value
        end
    end
    return content
end
function m:is_image_patch_node(patch)
    if not next(self.image_patch) then
        return
    end
    for _, v in pairs(self.image_patch) do
        for _, vv in pairs(v) do
            if patch.file == vv.file and patch.path == vv.path then
                return true
            end
        end
    end
end
function m:get_origin_patch_list(template_list)
    for _, patch in ipairs(self.origin_patch_template) do
        if self:is_image_patch_node(patch) or patch.file == self.anim_file or patch.path == self.anim_file then
            goto continue
        end
        if patch.file ~= self.prefab_name and patch.path ~= "hitch.prefab" then
            local find_mtl = false
            for key, _ in pairs(self.patch_copy_material) do
                if patch.path == key or patch.value == key or patch.file == key then
                    find_mtl = true
                    break
                end
            end
            if not find_mtl then
                template_list[#template_list + 1] = patch
            end
        end
        ::continue::
    end
end

function m:get_patch_list(template_list)
    for _, patch in ipairs(self.anim_patch) do
        template_list[#template_list + 1] = patch
    end
    local template = hierarchy:get_prefab_template(true)
    for i = 2, #template do
        local tpl = template[i]
        if tpl.mount and tpl.mount > 1 then
            tpl.mount = tpl.mount + (self.patch_start_index - 2)
        end
        template_list[#template_list + 1] = {
            file = self.prefab_name,
            op = "add",
            path = "/-",
            value = tpl
        }
    end
    for _, patch in ipairs(self.patch_template) do
        if not (patch.op == "add" and patch.path == "/-") then
            template_list[#template_list + 1] = patch
        end
    end
    return template_list
end

function m:save(path)
    if not gd.repo then
        widget_utils.message_box({title = "SaveError", info = "no project is opened"})
        return
    end
    -- patch glb file
    if self.glb_filename then
        if self.patch_template then
            local final_template = {}
            for _, v in ipairs(self.tag_patch) do
                final_template[#final_template + 1] = v
            end
            if next(self.image_patch) then
                for _, v in pairs(self.image_patch) do
                    for _, vv in pairs(v) do
                        final_template[#final_template + 1] = vv
                    end
                end
            end
            if self.patch_copy_material then
                for _, copy_material in pairs(self.patch_copy_material) do
                    if copy_material.copy then
                        final_template[#final_template + 1] = copy_material.copy
                    end
                    for _, mtlpatch in ipairs(copy_material.modify) do
                        final_template[#final_template + 1] = mtlpatch
                    end
                end
            end
            if self.prefab_name == "mesh.prefab" then
                local origin_template = {}
                self:get_patch_list(origin_template)
                local copy_file = {}
                for _, value in ipairs(origin_template) do
                    if value.op == 'copyfile' then
                        copy_file[#copy_file + 1] = value
                    else
                        final_template[#final_template + 1] = value
                    end
                end
                for _, value in ipairs(copy_file) do
                    final_template[#final_template + 1] = value
                end
                
                self:get_origin_patch_list(final_template)
            else
                self:get_origin_patch_list(final_template)
                self:get_patch_list(final_template)
            end
            if self.save_hitch then
                local hitch = self:get_hitch_content()
                if hitch and #hitch > 0 then
                    final_template[#final_template + 1] = {
                        file = "mesh.prefab",
                        op = "createfile",
                        path = "hitch.prefab",
                        value = hitch
                    }
                end
            end
            if #final_template > 0 then
                utils.write_file(self.glb_filename..".patch", stringify(final_template))
                assetmgr.unload(gd.virtual_prefab_path.."/" .. self.anim_file)
                assetmgr.unload(self.glb_filename..".patch")
                assetmgr.unload(self.glb_filename.."|"..self.prefab_name)
                anim_view.save_keyevent()
                world:pub {"ResourceBrowser", "dirty"}
            end
        end
        return
    end
    local lpath = self.prefab_filename
    if not path then
        if not self.prefab_filename or (string.find(self.prefab_filename, "__temp__")) then
            lpath = widget_utils.get_saveas_path("Prefab", "prefab")
            if not lpath then
                return
            end
            path = tostring(access.virtualpath(gd.repo, lpath))
        end
    end
    assert(path or self.prefab_filename)
    local prefab_filename = self.prefab_filename or ""
    local filename = path or prefab_filename
    local saveas = (lfs.path(filename) ~= lfs.path(prefab_filename))
    local template = hierarchy:get_prefab_template()
    utils.write_file(lpath, stringify(template))
    memfs.update(filename, lpath)
    if saveas then
        self:open(lpath)
        world:pub {"WindowTitle", filename}
    end
    if prefab_filename then
        world:remove_template(prefab_filename)
    end
    anim_view.save_keyevent()
    world:pub {"ResourceBrowser", "dirty"}
end

function m:set_parent(target, parent)
    local te <close> = world:entity(target, "scene?in")
    if te.scene then
        local function new_entity(eid, scene)
            local ni = hierarchy:get_node_info(eid)
            local tpl = ni.template
            tpl.data.scene = scene
            local e = world:create_entity(utils.deep_copy(tpl))
            self:add_entity(e, scene.parent, tpl)
            hierarchy:get_node_info(e).name = ni.name
            return e
        end
        local function create_tree(eid, scene)
            local e = new_entity(eid, scene)
            local tn = hierarchy:get_node(eid)
            for _, ce in ipairs(tn.children) do
                local tpl = hierarchy:get_node_info(ce.eid).template
                create_tree(ce.eid, {parent = e, s = tpl.data.scene.s, r = tpl.data.scene.r, t = tpl.data.scene.t})
            end
            return e
        end

        local targetWorldMat = mc.IDENTITY_MAT
        if parent then
            local se <close> = world:entity(parent, "scene?in")
            targetWorldMat = iom.worldmat(se)
        end
        local s, r, t = math3d.srt(math3d.mul(math3d.inverse(targetWorldMat), iom.worldmat(te)))
        local e = create_tree(target, {
            parent = parent,
            s = {math3d.index(s, 1), math3d.index(s, 2), math3d.index(s, 3)},
            r = {math3d.index(r, 1), math3d.index(r, 2), math3d.index(r, 3), math3d.index(r, 4)},
            t = {math3d.index(t, 1), math3d.index(t, 2), math3d.index(t, 3)}
        })
        local function remove_tree(eid)
            local tn = hierarchy:get_node(eid)
            for _, ce in ipairs(tn.children) do
                remove_tree(ce.eid)
            end
            self:remove_entity(eid)
        end
        remove_tree(target)
        return e
    end
end

function m:update_tag_list()
    local srt_mtl_list = {""}
    local mtl_list = {""}
    local efk_list = {}
    for k, value in pairs(self.current_prefab.tag) do
        if k ~= "*" and k ~= "animation" then
            for _, eid in ipairs(value) do
                local ee <close> = world:entity(eid, "scene?in material?in")
                if ee.scene or ee.material then
                    srt_mtl_list[#srt_mtl_list + 1] = k
                    if ee.material then
                        mtl_list[#mtl_list + 1] = k
                    end
                elseif ee.efk then
                    efk_list[#efk_list + 1] = k
                end
            end
        end
    end
    self.efk_list = efk_list
    self.srt_mtl_list = srt_mtl_list
    self.mtl_list = mtl_list
end

function m:do_remove_entity(eid)
    if not eid then
        return
    end
    local en = hierarchy:get_node(eid)
    if not en or en.temporary then
        return
    end
    if en.children then
        for i = #en.children, 1, -1 do
            self:do_remove_entity(en.children[i])
        end
    end
    if not self:pacth_remove(eid) then
        return
    end
    remove_entity_self(eid)
    local index
    for idx, entity in ipairs(self.entities) do
        if entity == eid then
            index = idx
            break
        end
    end
    if index then
        table.remove(self.entities, index)
    end
end
function m:remove_entity(eid)
    self:do_remove_entity(eid)
    hierarchy:update_slot_list(world)
    gizmo:set_target(nil)
    world:pub {"UpdateAABB"}
end

function m:get_current_filename()
    return self.prefab_filename
end
function m:get_root_mat()
    return self.root_mat
end
function m.set_anim_view(aview)
    anim_view = aview
end
function m:get_eid_by_name(name)
    for _, eid in ipairs(self.entities) do
        local info = hierarchy:get_node_info(eid)
        if info.name == name then
            return eid
        end
    end
end
function m:get_world_aabb(eid)
    local info = hierarchy:get_node_info(eid)
    local children
    if info.filename then
        children = hierarchy:get_select_adaptee(eid)
    else
        local node = hierarchy:get_node(eid)
        children = {}
        for _, n in ipairs(node.children) do
            children[#children + 1] = n.eid
        end
    end
    local waabb
    local e <close> = world:entity(eid, "bounding?in")-- meshskin?in")
    local bbox = e.bounding
    if bbox and bbox.scene_aabb and bbox.scene_aabb ~= mc.NULL then
        waabb = math3d.aabb(math3d.array_index(bbox.scene_aabb, 1), math3d.array_index(bbox.scene_aabb, 2))
    end
    for _, c in ipairs(children) do
        local ec <close> = world:entity(c, "bounding?in")
        local bounding = ec.bounding
        if bounding and bounding.scene_aabb and bounding.scene_aabb ~= mc.NULL then
            if not waabb then
                waabb = math3d.aabb(math3d.array_index(bounding.scene_aabb, 1), math3d.array_index(bounding.scene_aabb, 2))
            else
                waabb = math3d.aabb_merge(bounding.scene_aabb, waabb)
            end
        end
    end
    -- TODO: if eid is scene root or meshskin, merge skinning node
    if (info.template.tag and info.template.tag[1] == "Scene") then-- or e.meshskin then
        for key, _ in pairs(hierarchy.all_node) do
            local ea <close> = world:entity(key, "bounding?in")-- skinning?in")
            local bounding = ea.bounding
            if bounding and bounding.scene_aabb and bounding.scene_aabb ~= mc.NULL then
            -- if ea.skinning and bounding and bounding.scene_aabb and bounding.scene_aabb ~= mc.NULL then
                if not waabb then
                    waabb = math3d.aabb(math3d.array_index(bounding.scene_aabb, 1), math3d.array_index(bounding.scene_aabb, 2))
                else
                    waabb = math3d.aabb_merge(bounding.scene_aabb, waabb)
                end
            end
        end
    end
    return waabb
end
-- modify patch file
function m:get_patch_node(path)
    for index, patch in ipairs(self.patch_template) do
        if patch.file == self.prefab_name and patch.path == path then
            return index, patch
        end
    end
end

function m:find_patch_index(node_idx)
    local true_idx
    for i = 1, #self.patch_template do
        local tpl = self.patch_template[i]
        if tpl.op == "add" and tpl.path == "/-" then
            node_idx = node_idx - 1
        end
        if node_idx == 0 then
            true_idx = i
            break
        end
    end
    return true_idx
end

function m:pacth_remove(eid)
    if not self.current_prefab then
        return true
    end
    local name = hierarchy:get_node_info(eid).template.tag[1]
    self.current_prefab.tag[name] = nil
    self:update_tag_list()
    if not self.glb_filename then
        return true
    end
    local info = hierarchy:get_node_info(eid)
    local is_prefab = info.filename
    local to_remove = info.template.index
    if to_remove < self.patch_start_index then
        return false
    end
    table.remove(self.prefab_template, to_remove)
    if is_prefab then
        table.remove(self.prefab_template, to_remove)
    end
    for i = to_remove, #self.prefab_template do
        local t = self.prefab_template[i]
        t.index = t.index - (is_prefab and 2 or 1)
    end
    local patch_index = self:find_patch_index(to_remove - self.patch_start_index + 1)
    table.remove(self.patch_template, patch_index)
    if is_prefab then
        table.remove(self.patch_template, patch_index)
    end
    return true
end

function m:pacth_add(tpl, embed)
    if not self.glb_filename then return end
    self.patch_template[#self.patch_template + 1] = {
        file = self.prefab_name,
        op = "add",
        path = "/-",
        value = tpl,
    }
    if embed then
        self.patch_template[#self.patch_template + 1] = {
            file = self.prefab_name,
            op = "add",
            path = "/-",
            value = embed,
        }
    end
end

function m:pacth_modify(pidx, p, v, origin_tag)
    if not self.glb_filename then return end
    local index
    local patch_node
    if pidx >= self.patch_start_index then
        local patch_index = self:find_patch_index(pidx - self.patch_start_index + 1)
        patch_node = self.patch_template[patch_index]
        assert(patch_node)
        local sep = "/"
        local current_value
        local last_value = patch_node.value
        local key
        for str in string.gmatch(p, "([^"..sep.."]+)") do
            if current_value then
                last_value = current_value
                key = str
            elseif str == "aabb" then
                last_value[key] = {}
                last_value = last_value[key]
                key = str
            else
                key = str
            end
            current_value = last_value[str]
        end
        if not v and key == "aabb" then
            patch_node.value["data"]["bounding"] = nil
        else
            last_value[key] = v
        end
    else
        local path = "/"..pidx..p
        index, patch_node = self:get_patch_node(path)
        if patch_node then
            if not v then
                table.remove(self.patch_template, index)
            else
                patch_node.value = v
            end
        elseif v then
            local sep = "/"
            local target
            for str in string.gmatch(path, "([^"..sep.."]+)") do
                if not target then
                    target = self.prefab_template[pidx][str]
                else
                    target = target[str]
                end
            end
            if origin_tag then
                self.tag_patch[#self.tag_patch + 1] = {
                    file = "mesh.prefab",
                    op = target and "replace" or "add",
                    path = path,
                    value = v,
                }
            else
                self.patch_template[#self.patch_template + 1] = {
                    file = self.prefab_name,
                    op = target and "replace" or "add",
                    path = path,
                    value = v,
                }
            end
        end
    end
end
local function get_origin_material_name(namemaps, name)
    if not namemaps then
        return
    end
    return namemaps[name]
end
function m:do_image_patch(image, path, v)
    local s, _ = string.find(image,"images/")
    if not s then
        return
    end
    local imgpath = string.sub(image, s)
    if not self.image_patch[imgpath] then
        self.image_patch[imgpath] = {}
    end
    self.image_patch[imgpath][path] = {
        file = imgpath,
        op = "add",
        path = path,
        value = v
    }
end
function m:do_material_patch(eid, path, v)
    local info = hierarchy:get_node_info(eid)
    local tpl = info.template
    if not self.materials_names then
        -- local ret = utils.split_ant_path(tpl.data.material)
        local fn = gd.virtual_prefab_path .. "/materials.names"
        self.materials_names = serialize.parse(fn, aio.readall(fn))
    end
    local origin = get_origin_material_name(self.materials_names, tostring(fs.path(tpl.data.material):stem()))
    if not origin then
        return
    end
    local copy_mtl = (self.prefab_name ~= "mesh.prefab")
    local mtl_path = "materials/"..origin.."_"..string.sub(self.prefab_name, 1, -8)..".material"
    origin = "materials/"..origin..".material"
    if copy_mtl then
        for _, opt in ipairs(self.origin_patch_template) do
            if opt.file == origin and opt.op == "copyfile" and opt.path == mtl_path then
                copy_mtl = false
                break
            end
        end
    end
    mtl_path = copy_mtl and mtl_path or origin

    local mtl_node = self.patch_copy_material[origin]
    if not mtl_node then
        mtl_node = {
            modify = {}
        }
        if copy_mtl then
            mtl_node.copy = {
                file = origin,
                op = "copyfile",
                path = mtl_path
            }
        end
        self.patch_copy_material[origin] = mtl_node
        for _, value in ipairs(self.origin_patch_template) do
            if value.file == mtl_path and value.op == "replace" then
                mtl_node.modify[#mtl_node.modify + 1] = value
            end
        end
    end
    if copy_mtl and not tpl.replace_mtl then
        self.patch_template[#self.patch_template + 1] = {
            file = self.prefab_name,
            op = "replace",
            path = "/"..tpl.index.."/data/material",
            value = mtl_path,
        }
        tpl.replace_mtl = true
    end
    local patch_node
    for _, patch in ipairs(mtl_node.modify) do
        if patch.file == mtl_path and patch.path == path then
            patch_node = patch
            break
        end
    end
    if patch_node then
        patch_node.value = v
    else
        mtl_node.modify[#mtl_node.modify + 1] = {
            file = mtl_path,
            op = "replace",
            path = path,
            value = v,
        }
    end
end

function m:do_patch(eid, path, v, origin_tag)
    local info = hierarchy:get_node_info(eid)
    self:pacth_modify(info.template.index, path, v, origin_tag)
end

function m:on_patch_tag(eid, ov, nv, origin_tag, update_tag)
    if not self.current_prefab then
        return
    end
    self:do_patch(eid, "/tag", #nv > 0 and nv or nil, origin_tag)
    local tag = self.current_prefab.tag
    if ov and ov[1] and tag[ov[1]] then
        tag[ov[1]] = nil
    end
    if #nv > 0 then
        tag[nv[1]] = {eid}
    end
    if update_tag then
        self:update_tag_list()
    end
end

function m:on_patch_tranform(eid, n, v)
    self:do_patch(eid, "/data/scene/"..n, v)
end

function m:on_patch_animation(eid, name, path)
    local anim_file_exists
    local remove_index
    local target_path = "/animations/" .. name
    for index, value in ipairs(self.anim_patch) do
        if value.file == "animations/animation.ozz" and value.path == self.anim_file then
            anim_file_exists = true
        end
        if not path and value.op == "replace" and value.file == self.anim_file and value.path == target_path then
            remove_index = index
            break
        end
    end
    -- delete animation
    if remove_index then
        table.remove(self.anim_patch, remove_index)
        return
    end
    if not anim_file_exists then
        self.anim_patch = {
            file = "animations/animation.ozz",
            op = "copyfile",
            path = self.anim_file,
        }
        self.patch_template[#self.patch_template + 1] = {
            file = self.prefab_name,
            op = "replace",
            path = "/2/data/animation",
            value = "./"..self.anim_file
        }
    end
    self.anim_patch[#self.anim_patch + 1] = {
        file = self.anim_file,
        op = path and "replace" or "remove",
        path = "/animations/"..name,
        value = path and path or nil,
    }
    anim_view.update_anim_namelist()
end
return m