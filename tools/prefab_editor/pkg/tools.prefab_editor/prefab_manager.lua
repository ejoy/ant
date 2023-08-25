local ecs = ...
local world = ecs.world
local w = world.w
local imgui         = require "imgui"
local assetmgr      = import_package "ant.asset"
local serialize     = import_package "ant.serialize"
local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant
local iom           = ecs.require "ant.objcontroller|obj_motion"
local irq           = ecs.require "ant.render|render_system.renderqueue"
local stringify     = import_package "ant.serialize".stringify
local ilight        = ecs.require "ant.render|light.light"
local iefk          = ecs.require "ant.efk|efk"
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
-- local subprocess    = import_package "ant.subprocess"

local anim_view
local m = {
    entities = {}
}

local lightidx = 0
local function gen_light_id() lightidx = lightidx + 1 return lightidx end

local geometricidx = 0
local function gen_geometry_id() geometricidx = geometricidx + 1 return geometricidx end

local function create_light_billboard(light_eid)
end

local geom_mesh_file = {
    ["cube"] = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/Cube_P1.meshbin",
    ["cone"] = "/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/Cone_P1.meshbin",
    ["cylinder"] = "/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/Cylinder_P1.meshbin",
    ["sphere"] = "/pkg/ant.resources.binary/meshes/base/sphere.glb|meshes/Sphere_P1.meshbin",
    ["torus"] = "/pkg/ant.resources.binary/meshes/base/torus.glb|meshes/Torus_P1.meshbin",
    ["plane"] = "/pkg/ant.resources.binary/meshes/base/plane.glb|meshes/Plane_P1.meshbin"
}

local group_id = 0
local function get_group_id()
    group_id = group_id + 1
    return group_id
end

local hitch_id = 1
function m:create_hitch(slot)
    local auto_name = (slot and "slot" or "hitch") .. hitch_id
    hitch_id = hitch_id + 1
    local parent_eid = gizmo.target_eid or (self.scene and self.scene or self.root)
    local template = {
        policy = {
            "ant.general|name"
        },
        data = {
            name = auto_name,
            scene = { parent = parent_eid }
        }
    }
    if slot then
        -- template.policy[#template.policy + 1] = "ant.general|tag"
        -- template.data.tag = { auto_name }
        template.policy[#template.policy + 1] = "ant.animation|slot"
        template.data.slot = {
            joint_name = "None",
            follow_flag = 1,
        }
    else
        template.policy[#template.policy + 1] = "ant.render|hitch_object"
        template.data.hitch = { group = 0 }
    end
    local tpl = utils.deep_copy(template)
    if slot then
        tpl.data.on_ready = function (e) hierarchy:update_slot_list(world) end
    end
    self:add_entity(ecs.create_entity(tpl), parent_eid, template)
end

local function create_simple_entity(name, parent)
    local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
		},
		data = {
            name = name,
            scene = {parent = parent},
            -- bounding = {aabb = {{0,0,0}, {1,1,1}}}
		},
    }
    return ecs.create_entity(utils.deep_copy(template)), template
end

function m:add_entity(new_entity, parent, tpl)
    self.entities[#self.entities+1] = new_entity
    if self.scene ~= new_entity then
        self.prefab_template[#self.prefab_template + 1] = tpl
        tpl.index = #self.prefab_template
        self:pacth_add(tpl)
    end
    hierarchy:add(new_entity, {template = tpl}, parent)
end

local function create_default_light(lt, parent)
    return ilight.create{
        srt = {t = {0, 5, 0}, r = {math.rad(130), 0, 0}, parent = parent},
        name            = lt .. gen_light_id(),
        type            = lt,
        color           = {1, 1, 1, 1},
        make_shadow     = false,
        intensity       = 130000,--ilight.default_intensity(lt),
        intensity_unit  = ilight.default_intensity_unit(lt),
        range           = 1,
        motion_type     = "dynamic",
        inner_radian    = math.rad(45),
        outter_radian   = math.rad(45)
    }
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
            filename = "/pkg/tools.prefab_editor/res/light.prefab"
        end
        self.light_prefab = filename
        if not self.default_light then
            self.default_light = ecs.create_instance(self.light_prefab)
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
        -- w:remove(self.plane)
        -- self.plane = nil
    else
        if not self.terrain then
            local iterrain  = ecs.require "mod.terrain|terrain_system"
            iterrain.gen_terrain_field(128, 128, 64, 10)
            self.terrain = true
        end
        -- self:create_ground()
    end
end
function m:clone(eid)
    local srctpl = hierarchy:get_template(eid)
    if srctpl.filename then
        return
    end
    local dsttpl = utils.deep_copy(srctpl.template)
    local tmp = utils.deep_copy(dsttpl)
    local e <close> = world:entity(eid, "name:in scene?in")
    if not e.scene then
        print("can not clone noscene node.")
        return
    end
    local name = e.name .. "_copy"
    tmp.data.name = name
    local pid = e.scene.parent > 0 and e.scene.parent or self.root
    tmp.data.scene.parent = pid
    if e.scene.slot then
        tmp.data.on_ready = function (obj) hierarchy:update_slot_list(world) end
    end
    local new_entity = ecs.create_entity(tmp)
    dsttpl.data.name = name
    self:add_entity(new_entity, pid, dsttpl)
end

function m:create(what, config)
    if not self.root then
        self:reset_prefab()
    end
    if what == "hitch" then
        self:create_hitch()
    elseif what == "slot" then
        self:create_hitch(true)
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
                    "ant.general|name",
                },
                data = {
                    scene = {t = {0, offsety , 0}},
                    visible_state = "main_view|selectable",
                    material = "/pkg/tools.prefab_editor/res/materials/pbr_default.material",
                    mesh = geom_mesh_file[config.type],
                    name = config.type .. gen_geometry_id(),
                }
            }
            local tmp = utils.deep_copy(template)
            local hitch
            if parent_eid then
                local pe <close> = world:entity(parent_eid, "hitch?in")
                hitch = pe.hitch
            end
            local new_entity
            if hitch then
                if hitch.group == 0 then
                    hitch.group = get_group_id()
                end
                local group = ecs.group(hitch.group)
                new_entity = group:create_entity(tmp)
            else
                tmp.data.scene.parent = parent_eid
                new_entity = ecs.create_entity(tmp)
            end

            self:add_entity(new_entity, parent_eid, template)
            return new_entity
        elseif config.type == "cube(prefab)" then
            m:add_prefab(gd.editor_package_path .. "res/cube.prefab")
        elseif config.type == "cone(prefab)" then
            m:add_prefab(gd.editor_package_path .. "res/cone.prefab")
        elseif config.type == "cylinder(prefab)" then
            m:add_prefab(gd.editor_package_path .. "res/cylinder.prefab")
        elseif config.type == "sphere(prefab)" then
            m:add_prefab(gd.editor_package_path .. "res/sphere.prefab")
        elseif config.type == "torus(prefab)" then
            m:add_prefab(gd.editor_package_path .. "res/torus.prefab")
        elseif config.type == "plane(prefab)" then
            m:add_prefab(gd.editor_package_path .. "res/plane.prefab")
        end
    elseif what == "light" then
        if config.type == "directional" or config.type == "point" or config.type == "spot" then
            local newlight, tpl = create_default_light(config.type, self.root)
            self:add_entity(newlight, self.root, tpl)
            light_gizmo.init()
            --create_light_billboard(newlight)
        end
    end
end

local function set_select_adapter(entity_set, mount_root)
    for _, e in ipairs(entity_set) do
        hierarchy:add_select_adapter(e, mount_root)
    end
end

local FBXTOGLB
function m:open_fbx(filename)
    if not FBXTOGLB then
        local blenderpath = editor_setting.setting.blender_path
        if blenderpath then
            if lfs.exists(lfs.path(blenderpath .. "/blender.exe")) then
                FBXTOGLB = subprocess.tool_exe_path(blenderpath .. "/blender")
            end
        end

        if not FBXTOGLB then
            log.warn "Can not find blender."
            return
        end
    end

    local fullpath = tostring(lfs.current_path() / fs.path(filename):localpath())
    local scriptpath = tostring(lfs.current_path()) .. "/tools/prefab_editor/Export.GLB.py"
    local commands = {
		FBXTOGLB,
        "--background",
        "--python",
        scriptpath,
        "--",
        fullpath
	}
    local ok, msg = subprocess.spawn_process(commands)
	if ok then
		local INFO = msg:upper()
		for _, term in ipairs {
			"ERROR",
			"FAILED TO CONVERT FBX FILE"
		} do
			if INFO:find(term, 1, true) then
				ok = false
				break
			end
		end
	end
	if not ok then
		return false, msg
	end
    local prefabFilename = string.sub(filename, 1, string.find(filename, ".fbx")) .. "glb"
    self:open(prefabFilename)
end

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
end

local nameidx = 0
local function gen_prefab_name() nameidx = nameidx + 1 return "prefab" .. nameidx end

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
            if not entity.scene or st_set[entity.scene.parent] == nil then
                break
            end
            st_set[entity.eid] = true
            st[#st + 1] = entitys[i]
        end
        return st
    end

    local node_map = {}

    local final_template = {}
    for idx, value in ipairs(self.prefab_template) do
        value.index = idx
        final_template[#final_template + 1] = value
    end
    -- if self.patch_template then
    --     for _, value in ipairs(self.patch_template) do
    --         final_template[#final_template + 1] = value
    --     end
    -- end

    local j = 1
    for idx, pt in ipairs(final_template) do
        local eid = entitys[j]
        local e <close> = world:entity(eid, "scene?in light?in")
        local scene = e.scene
        local parent = scene and find_e(entitys, scene.parent)
        if pt.prefab then
            local children = sub_tree(parent, j)
            j = j + #children
            local target_node = node_map[parent]
            target_node.children = children
            target_node.filename = pt.prefab
            target_node.editor = pt.editor or false
        else
            self.entities[#self.entities + 1] = eid
            node_map[eid] = {template = pt, parent = parent}
            j = j + 1
        end

        if e.light then
            create_light_billboard(eid)
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
        local children = node.children
        local tp = node.template
        if children then
            set_select_adapter(children, eid)
            tp = {template = node.template, filename = node.filename, editor = node.editor}
        else
            tp = {template = node.template}
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
end

local function read_file(fn)
    local f<close> = assert(io.open(fn:string()))
    return f:read "a"
end

local function check_animation(template)
    local has_animation = false
    local anim_template
    for _, tpl in ipairs(template) do
        if not anim_template and tpl.data.mesh then
            local mesh_file = tpl.data.mesh
            local pos = string.find(mesh_file, ".glb|")
            local anim_path = string.sub(mesh_file, 1, pos + 4) .. "animation.prefab"
            if fs.exists(anim_path) then
                anim_template = serialize.parse(anim_path, read_file(lfs.path(assetmgr.compile(anim_path))))
            end
        end
        if tpl.data.animation then
            has_animation = true
            break
        end
    end
    if not has_animation and anim_template then
        template[#template + 1] = anim_template
    end
end

local prefabe_name_ui = {text = ""}
local prefab_list = {}
local selected_prefab
local patch_template
local faicons   = require "common.fa_icons"
local function reset_open_context()
    gd.glb_filename = nil
    prefab_list = {}
    prefabe_name_ui = {text = ""}
end
function m:choose_prefab()
    if not gd.glb_filename then
        return
    end
    if #prefab_list < 1 then
        local patchfile = tostring(gd.glb_filename) .. ".patch"
        patch_template = fs.exists(fs.path(patchfile)) and serialize.parse(patchfile, read_file(lfs.path(assetmgr.compile(patchfile)))) or {}
        local prefab_set = {}
        for _, patch in ipairs(patch_template) do
            local k = (patch.file ~= "mesh.prefab") and patch.file or ((patch.op == "copyfile") and patch.value or nil)
            if k then
                prefab_set[k] = true
            end
        end
        prefab_list = {"mesh.prefab"}
        for key, _ in pairs(prefab_set) do
            prefab_list[#prefab_list + 1] = key
        end
    end

    local title = "Choose prefab"
    if not imgui.windows.IsPopupOpen(title) then
        imgui.windows.OpenPopup(title)
    end
    local change, opened = imgui.windows.BeginPopupModal(title, imgui.flags.Window{"AlwaysAutoResize", "NoClosed"})
    if change then
        imgui.widget.Text("Create new or open existing prefab.")
        if imgui.widget.InputText("##PrefabName", prefabe_name_ui) then
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(faicons.ICON_FA_FOLDER_PLUS.." Create") then
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
                    table.insert(patch_template, 1, {
                        file = "mesh.prefab",
                        op = "copyfile",
                        value = prefab_list[#prefab_list]
                    })
                    utils.write_file(tostring(gd.glb_filename)..".patch", stringify(patch_template))
                end
            end
        end
        imgui.cursor.Separator()
        for _, n in ipairs(prefab_list) do
            if imgui.widget.Selectable(n, selected_prefab and selected_prefab == n, 0, 0, imgui.flags.Selectable {"AllowDoubleClick"}) then
                selected_prefab = n
                -- if imgui.util.IsMouseDoubleClicked(0) then
                    self:open(tostring(gd.glb_filename) .. "|" .. selected_prefab, selected_prefab, patch_template)
                -- end
            end
        end
        imgui.cursor.Separator()
        if imgui.widget.Button(faicons.ICON_FA_FOLDER_OPEN.." Open") then
            if selected_prefab then
                self:open(tostring(gd.glb_filename) .. "|" .. selected_prefab, selected_prefab, patch_template)
            end
        end
        imgui.cursor.SameLine()
        if imgui.widget.Button(faicons.ICON_FA_BAN.." Quit") then
            reset_open_context()
            imgui.windows.CloseCurrentPopup()
        end
        imgui.windows.EndPopup()
    end
end

function m:open(filename, prefab_name, patch_tpl)
    assert(prefab_name and patch_tpl)
    reset_open_context()
    self:reset_prefab(true)
    local path_list = split(filename)
    if #path_list > 1 then
        self.glb_filename = path_list[1]
    end
    self.prefab_name = prefab_name or "mesh.prefab"
    -- if path:equal_extension(".fbx") then
    --     self:open_fbx(tostring(path))
    -- elseif path:equal_extension(".glb") then
    --     filename = filename .. "|" .. self.prefab_name
    -- end
    self.prefab_filename = filename
    self.prefab_template = serialize.parse(filename, read_file(lfs.path(assetmgr.compile(filename))))
    if self.glb_filename then
        self.patch_template = patch_tpl or {}
        for index, value in ipairs(self.patch_template) do
            if value.file == self.prefab_name and value.op == "add" then
                self.patch_index_map[#self.patch_index_map + 1] = index
            end
        end
        self.patch_start_index = #self.prefab_template - #self.patch_index_map + 1
    end

    for _, value in ipairs(self.prefab_template) do
        if value.data and value.data.efk then
            self.check_effect_preload(value.data.efk.path)
        end
    end
    -- check_animation(self.prefab_template)

    local prefab = ecs.create_instance(filename)
    function prefab:on_init() end
    prefab.on_ready = function(instance)
        self:on_prefab_ready(instance)
        hierarchy:update_slot_list(world)
        anim_view.on_prefab_load(self.entities)
        world:pub {"LookAtTarget", self.entities[1]}
    end
    world:create_object(prefab)
    editor_setting.add_recent_file(filename)
    editor_setting.save()
    world:pub {"WindowTitle", filename}
end

local function remove_entity_self(eid)
    local e <close> = world:entity(eid, "light?in")
    if e.light then
        light_gizmo.on_remove_light(eid)
    end
    local en = hierarchy:get_node(eid)
    if en.prefab then
        -- TODO: for camera, remove this for
        for i = #en.children, 1, -1 do
            hierarchy:del(en.children[i])
        end
        for _, id in ipairs(en.prefab.tag["*"]) do
            w:remove(id)
        end
    end
    local teml = hierarchy:get_template(eid)
    if teml and teml.children then
        hierarchy:clear_adapter(eid)
    end
    hierarchy:del(eid)
    w:remove(eid)
end

local imaterial = ecs.require "ant.asset|material"

function m:create_ground()
    if not self.plane then
        self.plane = ecs.create_entity {
            policy = {
                "ant.render|render",
                "ant.general|name",
            },
            data = {
                scene = {s = {200, 1, 200}},
                mesh  = "/pkg/tools.prefab_editor/res/plane.glb|meshes/Plane_P1.meshbin",
                material    = "/pkg/tools.prefab_editor/res/materials/texture_plane.material",
                render_layer = "background",
                visible_state= "main_view",
                name        = "ground",
                on_ready = function (e)
                    -- ivs.set_state(e, "main_view", false)
                    imaterial.set_property(e, "u_uvmotion", math3d.vector{0, 0, 100, 100})
                end
            },
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
        ecs.release_cache(self.prefab_filename)
    end
    -- for _, value in ipairs(assetmgr.textures) do
    --     -- value:unload()
    --     print(value)
    -- end
    gizmo:set_target()
    self:create_ground()
    self.prefab_template = {}
    self.patch_template = {}
    self.patch_index_map = {}
    self.prefab_filename = nil
    self.glb_filename = nil
    self.scene = nil
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
        irq.set_camera("main_queue", self.main_camera)
        irq.set_visible("second_view", false)
    end
end

function m:reload()
    local filename = self.prefab_filename
    if filename == 'nil' then
        self:save((gd.project_root / "res/__temp__.prefab"):string())
    else
        self:open(filename, self.prefab_name, self.patch_template)
    end
end
local global_data       = require "common.global_data"
local access            = global_data.repo_access

-- preload all textures for effect
function m.check_effect_preload(filename)
    local path = filename:match("^(.+/)[%w*?_.%-]*$")
    local files = access.list_files(global_data.repo, path)
    local texture_files = {}
    for _, value in ipairs(files) do
        if string.sub(value, -8) == ".texture" then
            texture_files[#texture_files + 1] = path..value
        end
    end
    if #texture_files > 0 then
        iefk.preload(texture_files)
    end
end

function m:add_effect(filename)
    self.check_effect_preload(filename)

    if not self.root then
        self:reset_prefab()
    end
    local parent = gizmo.target_eid or (self.scene and self.scene or self.root)
    local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.efk|efk",
            -- "ant.general|tag"
		},
		data = {
            name = fs.path(filename):stem():string(),
            -- tag = {"effect"},
            scene = {parent = parent},
            efk = {
                path = filename,
                auto_play = false,
                loop = false,
                speed = 1.0,
                visible = true
            }
		},
    }
    local tpl = utils.deep_copy(template)
    tpl.data.efk.auto_play = true
    self:add_entity(ecs.create_entity(tpl), parent, template)
end

function m:add_prefab(path)
    local prefab_filename = path
    if string.sub(path, -4) == ".glb" then
        prefab_filename = path .. "|mesh.prefab"
    end
    
    if not self.root then
        self:reset_prefab()
    end
    local prefab
    local parent = gizmo.target_eid or (self.scene and self.scene or self.root)
    local v_root, temp = create_simple_entity(tostring(fs.path(path):filename()), parent)
    -- local v_root, temp = create_simple_entity(gen_prefab_name(), parent)
    self.entities[#self.entities+1] = v_root
    prefab = ecs.create_instance(prefab_filename, v_root)
    prefab.on_ready = function(inst)
        local children = inst.tag["*"]
        if #children == 1 then
            local child = children[1]
            local e <close> = world:entity(child, "camera?in")
            if e.camera then
                local temp = serialize.parse(prefab_filename, read_file(lfs.path(assetmgr.compile(prefab_filename))))
                hierarchy:add(child, {template = temp[1], editor = true, temporary = true}, v_root)
                return
            end
        end
        set_select_adapter(children, v_root)
    end
    world:create_object(prefab)
    local node = hierarchy:add(v_root, {template = temp, filename = prefab_filename, editor = false}, parent)
    node.prefab = prefab
end

function m:save(path)
    -- patch glb file
    if self.glb_filename then
        if self.patch_template then
            utils.write_file(self.glb_filename..".patch", stringify(self.patch_template))
            assetmgr.unload(self.glb_filename..".patch")
            assetmgr.unload(self.glb_filename.."|"..self.prefab_name)
            anim_view.save_keyevent()
            world:pub {"ResourceBrowser", "dirty"}
        end
        return
    end
    if not path then
        if not self.prefab_filename or (string.find(self.prefab_filename, "__temp__")) then
            path = widget_utils.get_saveas_path("Prefab", "prefab")
        end
    end
    assert(path or self.prefab_filename)
    local prefab_filename = self.prefab_filename or ""
    local filename = path or prefab_filename
    local saveas = (lfs.path(filename) ~= lfs.path(prefab_filename))
    local template = hierarchy:get_prefab_template()
    utils.write_file(filename, stringify(template))
    if saveas then
        self:open(filename)
        world:pub {"WindowTitle", filename}
    end
    if prefab_filename then
        ecs.release_cache(prefab_filename)
    end
    anim_view.save_keyevent()
    world:pub {"ResourceBrowser", "dirty"}
end

function m:set_parent(target, parent)
    local te <close> = world:entity(target, "scene?in")
    if te.scene then
        local function new_entity(te, pe, scene)
            local template = hierarchy:get_template(te).template
            local tpl = utils.deep_copy(template)
            if scene then
                tpl.data.scene = scene
                template.data.scene.s = scene.s
                template.data.scene.r = scene.r
                template.data.scene.t = scene.t
            end
            local e = ecs.create_entity(tpl)
            self:add_entity(e, pe, template)
            return e
        end
        local function create_tree(te, pe, scene)
            local npe = new_entity(te, pe, scene)
            local tn = hierarchy:get_node(te)
            for _, ce in ipairs(tn.children) do
                local tpl = hierarchy:get_template(ce.eid).template
                create_tree(ce.eid, npe, {parent = npe, s = tpl.data.scene.s, r = tpl.data.scene.r, t = tpl.data.scene.t })
            end
            return npe
        end

        local targetWorldMat = mc.IDENTITY_MAT
        if parent then
            local se <close> = world:entity(parent, "scene?in")
            targetWorldMat = iom.worldmat(se)
        end
        local ts, tr, tt = math3d.srt(math3d.mul(math3d.inverse(targetWorldMat), iom.worldmat(te)))
        ts = math3d.tovalue(ts)
        tr = math3d.tovalue(tr)
        tt = math3d.tovalue(tt)
        local s, r, t = {ts[1], ts[2], ts[3]}, tr, {tt[1], tt[2], tt[3]}
        local e = create_tree(target, parent, {parent = parent, s = s, r = r, t = t})
        local function remove_tree(te)
            local tn = hierarchy:get_node(te)
            for _, ce in ipairs(tn.children) do
                remove_tree(ce.eid)
            end
            self:remove_entity(te)
        end
        remove_tree(target)
        return e
    end
end
function m:do_remove_entity(eid)
    if not eid then
        return
    end
    local en = hierarchy:get_node(eid)
    if not en.prefab then
        for i = #en.children, 1, -1 do
            self:do_remove_entity(en.children[i])
        end
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
    if not self:pacth_remove(eid) then
        return
    end
    self:do_remove_entity(eid)
    hierarchy:update_slot_list(world)
    hierarchy:update_collider_list(world)
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
        local e <close> = world:entity(eid, "name?in")
        if e.name == name then
            return eid
        end
    end
end
function m:get_world_aabb(eid)
    local tpl = hierarchy:get_template(eid)
    local children
    if tpl.filename then
        children = hierarchy:get_select_adaptee(eid)
    else
        local node = hierarchy:get_node(eid)
        children = {}
        for _, n in ipairs(node.children) do
            children[#children + 1] = n.eid
        end
    end
    local waabb
    local e <close> = world:entity(eid, "bounding?in meshskin?in name:in")
    local bounding = e.bounding
    if bounding and bounding.scene_aabb and bounding.scene_aabb ~= mc.NULL then
        waabb = math3d.aabb(math3d.array_index(bounding.scene_aabb, 1), math3d.array_index(bounding.scene_aabb, 2))
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
    if e.name == "Scene" or e.meshskin then
        for key, _ in pairs(hierarchy.all_node) do
            local ea <close> = world:entity(key, "bounding?in skinning?in")
            local bounding = ea.bounding
            if ea.skinning and bounding and bounding.scene_aabb and bounding.scene_aabb ~= mc.NULL then
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

function m:pacth_remove(eid)
    if not self.glb_filename then return end
    local tpl = hierarchy:get_template(eid)
    local pidx = tpl.template.index
    if pidx < self.patch_start_index then
        return false
    end
    table.remove(self.prefab_template, pidx)
    table.remove(self.patch_template, self.patch_index_map[pidx - self.patch_start_index + 1])
    table.remove(self.patch_index_map, pidx - self.patch_start_index + 1)
    return true
end

function m:pacth_add(template)
    if not self.glb_filename then return end
    local tpl = utils.deep_copy(template)
    tpl.index = nil
    local parent = tpl.data.scene.parent
    if parent then
        local parent_tpl = hierarchy:get_template(parent)
        tpl.data.scene.parent = nil
        tpl.mount = parent_tpl.template.index
    end
    self.patch_template[#self.patch_template + 1] = {
        file = self.prefab_name,
        op = "add",
        path = "/-",
        value = tpl
    }
    self.patch_index_map[#self.patch_index_map + 1] = #self.patch_template
end

function m:pacth_modify(pidx, p, v)
    if not self.glb_filename then return end
    local index
    local patch_node
    if pidx >= self.patch_start_index then
        patch_node = self.patch_template[self.patch_index_map[pidx - self.patch_start_index + 1]]
        assert(patch_node)
        local sep = "/"
        local current_value
        local last_value = patch_node.value
        local key
        for str in string.gmatch(p, "([^"..sep.."]+)") do
            if current_value then
                last_value = current_value
                key = str
            end
            current_value = last_value[str]
        end
        last_value[key] = v
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
            self.patch_template[#self.patch_template + 1] = {
                file = self.prefab_name,
                op = "replace",
                path = path,
                value = v,
            }
        end
    end
end

function m:on_patch_name(eid, v)
    local tpl = hierarchy:get_template(eid)
    self:pacth_modify(tpl.template.index, "/data/name", v)
end

function m:on_patch_tranform(eid, n, v)
    local tpl = hierarchy:get_template(eid)
    self:pacth_modify(tpl.template.index, "/data/scene/"..n, v)
end

function m:on_patch_animation(eid, name, path)
    local tpl = hierarchy:get_template(eid)
    self:pacth_modify(tpl.template.index, "/data/animation/"..name, path)
end
return m