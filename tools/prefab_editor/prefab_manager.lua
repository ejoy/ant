local ecs = ...
local world = ecs.world
local w = world.w
local cr            = import_package "ant.compile_resource"
local serialize     = import_package "ant.serialize"
local worldedit     = import_package "ant.editor".worldedit(world)
local assetmgr      = import_package "ant.asset"
local stringify     = import_package "ant.serialize".stringify
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local ies           = ecs.import.interface "ant.scene|ifilter_state"
local ilight        = ecs.import.interface "ant.render|ilight"
local imaterial     = ecs.import.interface "ant.asset|imaterial"
local icamera_recorder = ecs.import.interface "ant.camera|icamera_recorder"
local isp 		= ecs.import.interface "ant.render|isystem_properties"
local camera_mgr    = ecs.require "camera.camera_manager"
local light_gizmo   = ecs.require "gizmo.light"
local gizmo         = ecs.require "gizmo.gizmo"
local geo_utils     = ecs.require "editor.geometry_utils"
local editor_setting = require "editor_setting"
local logger        = require "widget.log"
local math3d 		= require "math3d"
local fs            = require "filesystem"
local lfs           = require "filesystem.local"
local vfs           = require "vfs"
local hierarchy     = require "hierarchy_edit"
local widget_utils  = require "widget.utils"
local bgfx          = require "bgfx"
local gd            = require "common.global_data"
local utils         = require "common.utils"
local effekseer     = require "effekseer"
local subprocess    = import_package "ant.subprocess"

local m = {
    entities = {}
}

local lightidx = 0
local function gen_light_id() lightidx = lightidx + 1 return lightidx end

local geometricidx = 0
local function gen_geometry_id() geometricidx = geometricidx + 1 return geometricidx end

local function create_light_billboard(light_eid)
    -- local bb_eid = world:deprecated_create_entity{
    --     policy = {
    --         "ant.render|render",
    --         "ant.effect|billboard",
    --         "ant.general|name"
    --     },
    --     data = {
    --         name = "billboard_light",
    --         transform = {},
    --         billboard = {lock = "camera"},
    --         filter_state = "main_view",
    --         scene_entity = true,
    --         material = gd.editor_package_path .. "res/materials/billboard.material"
    --     },
    --     action = {
    --         bind_billboard_camera = "camera"
    --     }
    -- }
    -- local icons = require "common.icons"(assetmgr)
    -- local type = world[light_eid].type
    -- local light_icons = {
    --     spot = "ICON_SPOTLIGHT",
    --     point = "ICON_POINTLIGHT",
    --     directional = "ICON_DIRECTIONALLIGHT",
    -- }
    -- local tex = icons[light_icons[type]].handle
    -- imaterial.set_property(bb_eid, "s_basecolor", {stage = 0, texture = {handle = tex}})
    -- iom.set_scale(bb_eid, 0.2)
    -- ies.set_state(bb_eid, "auxgeom", true)
    -- iom.set_position(bb_eid, iom.get_position(light_eid))
    -- world[bb_eid].parent = world[light_eid].parent
    -- light_gizmo.billboard[light_eid] = bb_eid
end

local geom_mesh_file = {
    ["cube"] = "/pkg/ant.resources.binary/meshes/base/cube.glb|meshes/pCube1_P1.meshbin",
    ["cone"] = "/pkg/ant.resources.binary/meshes/base/cone.glb|meshes/pCone1_P1.meshbin",
    ["cylinder"] = "/pkg/ant.resources.binary/meshes/base/cylinder.glb|meshes/pCylinder1_P1.meshbin",
    ["sphere"] = "/pkg/ant.resources.binary/meshes/base/sphere.glb|meshes/pSphere1_P1.meshbin",
    ["torus"] = "/pkg/ant.resources.binary/meshes/base/torus.glb|meshes/pTorus1_P1.meshbin"
}

local default_collider_define = {
    ["sphere"] = {{origin = {0, 0, 0, 1}, radius = 0.1}},
    ["box"] = {{origin = {0, 0, 0, 1}, size = {0.05, 0.05, 0.05} }},
    ["capsule"] = {{origin = {0, 0, 0, 1}, height = 1.0, radius = 0.25}}
}

local function get_local_transform(tran, parent_eid)
    if not parent_eid then return tran end
    local parent_worldmat = iom.worldmat(parent_eid)
    local worldmat = math3d.matrix(tran)
    local s, r, t = math3d.srt(math3d.mul(math3d.inverse(parent_worldmat), worldmat))
    local ts, tr, tt = math3d.totable(s), math3d.totable(r), math3d.totable(t)
    return {s = {ts[1], ts[2], ts[3]}, r = {tr[1], tr[2], tr[3], tr[4]}, t = {tt[1], tt[2], tt[3]}}
end

local slot_entity_id = 1
function m:create_slot()
    --if not gizmo.target_eid then return end
    local auto_name = "empty" .. slot_entity_id
    local parent_eid = gizmo.target_eid or self.root
    local template = {
        policy = {
            "ant.general|name",
            "ant.general|tag",
            "ant.scene|slot",
            "ant.scene|scene_object",
        },
        data = {
            reference = true,
            scene = {srt = {}},
            slot = {
                joint_name = "None",
                follow_flag = 1,
            },
            name = auto_name,
            tag = {auto_name},
        }
    }

    local tpl = utils.deep_copy(template)
    tpl.data.on_ready = function (e)
        hierarchy:update_slot_list(world)
    end
    local new_entity = ecs.create_entity(tpl)
    slot_entity_id = slot_entity_id + 1
    self:add_entity(new_entity, parent_eid, template)
end

function m:create_collider(config)
    if config.type ~= "sphere" and config.type ~= "box" then return end
    local scale = {}
    local define = config.define or default_collider_define[config.type]
    if config.type == "sphere" then
        scale = define[1].radius * 100
    elseif config.type == "box" then
        local size = define[1].size
        scale = {size[1] * 200, size[2] * 200, size[3] * 200}
    elseif config.type == "capsule" then
    end
    local template = {
        policy = {
            "ant.general|name",
            "ant.render|render",
            "ant.general|tag",
        },
        data = {
            reference = true,
            name = "collider" .. gen_geometry_id(),
            tag = config.tag or {"collider"},
            scene = {srt = {s = scale}, parent = self.root},
            filter_state = "main_view|selectable",
            material = "/pkg/ant.resources/materials/singlecolor_translucent.material",
            mesh = (config.type == "box") and geom_mesh_file["cube"] or geom_mesh_file[config.type],
            render_object = {},
            filter_material = {}
        }
    }
    local tpl = utils.deep_copy(template)
    tpl.data.on_ready = function (e)
        e.collider = { [config.type] = define }
        imaterial.set_property(e, "u_color", {1, 0.5, 0.5, 0.8})
    end
    return ecs.create_entity(tpl), template
end

local function create_simple_entity(name, srt)
    local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
		},
		data = {
            reference = true,
            name = name,
            scene = {srt = srt or {}}
		},
    }
    return ecs.create_entity(utils.deep_copy(template)), template
end

function m:add_entity(new_entity, parent, temp, no_hierarchy)
    self.entities[#self.entities+1] = new_entity
    ecs.method.set_parent(new_entity, parent or self.root)
    if not no_hierarchy then
        hierarchy:add(new_entity, {template = temp}, parent)--world[new_entity].parent)
    end
end

function m:find_entity(e)
    if not e.scene then
        w:sync("scene:in", e)
    end
    for _, entity in ipairs(self.entities) do
        if not entity.scene then
            w:sync("scene:in", entity)
        end
        if entity.scene.id == e.scene.id then
            return entity
        end
    end
end
local function create_default_light(lt)
    return ilight.create{
        srt = {t = {0, 3, 0}, r = {math.rad(130), 0, 0}},
        name            = lt .. gen_light_id(),
        type            = lt,
        color           = {1, 1, 1, 1},
        make_shadow     = false,
        intensity       = ilight.default_intensity(lt),
        intensity_unit  = ilight.default_intensity_unit(lt),
        range           = 1,
        motion_type     = "dynamic",
        inner_radian    = math.rad(45),
        outter_radian   = math.rad(45)
    }
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
        local new_entity, temp = create_simple_entity("empty" .. gen_geometry_id())
        self:add_entity(new_entity, gizmo.target_eid, temp)
    elseif what == "geometry" then
        if config.type == "cube"
            or config.type == "cone"
            or config.type == "cylinder"
            or config.type == "sphere"
            or config.type == "torus" then
            local parent_eid = config.parent or gizmo.target_eid
            local template = {
                policy = {
                    "ant.render|render",
                    "ant.general|name",
                },
                data = {
                    reference = true,
                    scene = {srt = {}},
                    filter_state = "main_view|selectable",
                    material = "/pkg/ant.resources/materials/pbr_default.material",
                    mesh = geom_mesh_file[config.type],
                    name = config.type .. gen_geometry_id()
                }
            }
            local new_entity = ecs.create_entity(utils.deep_copy(template))

            --imaterial.set_property(new_entity, "u_color", {1, 1, 1, 1})
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
        end
    elseif what == "enable_default_light" then
        if not self.default_light then
            local newlight, _ = create_default_light("directional")
            self.default_light = newlight
            if not self.skybox then
                self.skybox = ecs.create_instance("res/skybox_test.prefab")
            end
        end
    elseif what == "disable_default_light" then
        if self.default_light then
            w:remove(self.default_light)
            self.default_light = nil
        end
        if self.skybox then
            w:remove(self.skybox.root)
            local all_entitys = self.skybox.tag["*"]
            for _, e in ipairs(all_entitys) do
                w:remove(e)
            end
            self.skybox = nil
        end
    elseif what == "terrain" then
        if config.type == "shape" then
            local ist = ecs.import.interface "ant.terrain|ishape_terrain"
            local function generate_terrain_fields(w, h)
                local shapetypes = ist.shape_types()

                local fields = {}
                for ih=1, h do
                    for iw=1, w do
                        local which = 3 --math.random(1, 3)
                        local height = 0.05 --math.random() * 0.05
                        fields[#fields+1] = {
                            type    = shapetypes[which],
                            height  = height,
                        }
                    end
                end

                return fields
            end

            local ww, hh = 32, 32
            local terrain_fields = generate_terrain_fields(ww, hh)
            local template = {
                policy = {
                    "ant.scene|scene_object",
                    "ant.terrain|shape_terrain",
                    "ant.general|name",
                },
                data = {
                    name = "shape_terrain_test",
                    reference   = true,
                    scene = {
                        srt = {
                            t = {-ww//2, 0.0, -hh//2},
                        }
                    },
                    shape_terrain = {
                        terrain_fields = terrain_fields,
                        width = ww,
                        height = hh,
                        section_size = math.max(1, ww > 4 and ww//4 or ww//2),
                        unit = 2,
                        edge = {
                            color = 0xffe5e5e5,
                            thickness = 0.08,
                        },
                    },
                    materials = {
                        shape = "/pkg/ant.resources/materials/shape_terrain.material",
                        edge = "/pkg/ant.resources/materials/shape_terrain_edge.material",
                    }
                }
            }
            local shapetarrain = ecs.create_entity(utils.deep_copy(template))
            self:add_entity(shapetarrain, self.root, template)
        end
    elseif what == "light" then
        if config.type == "directional" or config.type == "point" or config.type == "spot" then
            local newlight, tpl = create_default_light(config.type)
            self:add_entity(newlight, self.root, tpl)
            light_gizmo.init()
            --create_light_billboard(newlight)
        end
    elseif what == "collider" then
        local new_entity, temp = self:create_collider(config)
        self:add_entity(new_entity, self.root, temp, not config.add_to_hierarchy)
        hierarchy:update_collider_list(world)
        return new_entity
    elseif what == "particle" then
        local entities = ecs.create_instance(gd.editor_package_path .. "res/particle.prefab")
        self:add_entity(entities[1], gizmo.target_eid, entities)
    end
end

function m:internal_remove(toremove)
    
end

local function set_select_adapter(entity_set, mount_root)
    for _, e in ipairs(entity_set) do
        hierarchy:add_select_adapter(e, mount_root)
    end
end

local function remove_entitys(entities)
    for _, e in ipairs(entities) do
        w:remove(e)
    end
end

local function get_prefab(filename)
    assetmgr.unload(filename)
    return worldedit:prefab_template(filename)
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
    local prefabFilename = string.sub(filename, 1, string.find(filename, ".fbx")) .. "glb|mesh.prefab"
    self:open(prefabFilename)
end

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
end

local function get_filename(pathname)
    pathname = pathname:lower()
    return pathname:match "[/]?([^/]*)$"
end

local function convert_path(path, glb_filename)
    if fs.path(path):is_absolute() then return path end
    local new_path
    if glb_filename then
        local pretty = tostring(lfs.path(path))
        if string.sub(path, 1, 2) == "./" then
            pretty = string.sub(path, 3)
        end
        new_path = glb_filename .. "|" .. pretty
    else
        -- local op_path = path
        -- local spec = string.find(path, '|')
        -- if spec then
        --     op_path = string.sub(path, 1, spec - 1)
        -- end
        -- new_path = tostring(lfs.relative(current_dir / lfs.path(op_path), new_dir))
        -- if spec then
        --     new_path = new_path .. string.sub(path, spec)
        -- end
    end
    return new_path
end

local nameidx = 0
local function gen_prefab_name() nameidx = nameidx + 1 return "prefab" .. nameidx end

function m:on_prefab_ready(prefab)
    local entitys = prefab.tag["*"]
    local function find_e(entitys, id)
        for _, e in ipairs(entitys) do
            if e.scene.id == id then
                return e
            end
        end
    end

    local function sub_tree(e, idx)
        local st = {}
        local st_set = {}
        st_set[e.scene.id] = true
        for i = idx, #entitys do
            local scene = entitys[i].scene
            if st_set[scene.parent] == nil then
                break
            end
            st_set[scene.id] = true
            st[#st + 1] = entitys[i]
        end
        return st
    end

    local node_map = {}

    local j = 1
    for i = 1, #self.prefab_template do
        local pt = self.prefab_template[i]
        local e = entitys[j]
        local parent = find_e(entitys, e.scene.parent)
        if pt.prefab then
            local prefab_name = pt.name or gen_prefab_name()
            local sub_root = create_simple_entity(prefab_name)
            ecs.method.set_parent(sub_root, parent)
            self.entities[#self.entities + 1] = sub_root

            local children = sub_tree(parent, j)
            for _, child in ipairs(children) do
                if child.scene.parent == parent.scene.id then
                    ecs.method.set_parent(child, sub_root)
                end
            end
            j = j + #children
            node_map[sub_root] = {template = {filename = pt.prefab, children = children, name = prefab_name, editor = pt.editor or false}, parent = parent}
        else
            self.entities[#self.entities + 1] = e
            node_map[e] = {template = self.prefab_template[i], parent = parent}
            j = j + 1
        end

        w:sync("light?in", e)
        if e.light then
            create_light_billboard(e)
            light_gizmo.bind(e)
            light_gizmo.show(false)
        end
    end

    local function add_to_hierarchy(e)
        local node = node_map[e]
        if node.parent and not hierarchy:get_node(node.parent) then
            add_to_hierarchy(node.parent)
        end
        local children = node.template.children
        local tp = node.template
        if children then
            set_select_adapter(children, e)
        else
            tp = {template = node.template}
        end
        hierarchy:add(e, tp, node.parent or self.root)
    end

    for _, e in ipairs(self.entities) do
        add_to_hierarchy(e)
    end
end

function m:open(filename)
    self:reset_prefab()
    world:pub {"PreOpenPrefab", filename}
    self.prefab_filename = filename
    self.prefab_template = serialize.parse(filename, cr.read_file(filename))

    local prefab = ecs.create_instance(filename)
    function prefab:on_init()
    end
    
    prefab.on_ready = function(instance)
        self:on_prefab_ready(instance)
        anim_view.load_clips()
    end
    
    function prefab:on_message(msg) end
    function prefab:on_update() end
    self.prefab_instance = world:create_object(prefab)
    editor_setting.add_recent_file(filename)
    editor_setting.save()
    world:pub {"WindowTitle", filename}
end

local function on_remove_entity(e)
    w:sync("light?in", e)
    if e.light then
        light_gizmo.on_remove_light(e)
    end
    local teml = hierarchy:get_template(e)
    if teml and teml.children then
        hierarchy:clear_adapter(e)
    end
    hierarchy:del(e)
end

function m:reset_prefab()
    camera_mgr.clear()
    for _, e in ipairs(self.entities) do
        if not e.scene.REMOVED then
            on_remove_entity(e)
            w:remove(e)
        end
    end
    light_gizmo.clear()
    hierarchy:clear()
    anim_view.clear()
    self.root = create_simple_entity("scene root")
    self.entities = {}
    world:pub {"WindowTitle", ""}
    world:pub {"ResetEditor", ""}
    hierarchy:set_root(self.root)
    self.prefab_filename = nil
    self.prefab_template = nil
    self.prefab_instance = nil
    gizmo.target_eid = nil
end

function m:reload()
    local filename = self.prefab_filename
    if filename == 'nil' then
        self:save_prefab(tostring(gd.project_root) .. "/res/__temp__.prefab")
    else
        self:open(filename)
    end
end

function m:add_effect(filename)
    if not self.root then
        self:reset_prefab()
    end
    local template = {
		policy = {
            "ant.general|name",
            "ant.scene|scene_object",
            "ant.effekseer|effekseer",
            "ant.general|tag"
		},
		data = {
            reference = true,
            name = "root",
            tag = {"effect"},
            scene = {srt = {}},
            effekseer = filename,
            effect_instance = {}
		},
    }
    local tpl = utils.deep_copy(template)
    tpl.data.on_ready = function (e)
        if not e.effect_instance then
            w:sync("effect_instance:in", e)
        end
        local inst = e.effect_instance
        if inst.handle == -1 then
            w:sync("effekseer:in", e)
            print("create effect faild : ", tostring(effekseer))
        end
        inst.playid = effekseer.play(inst.handle, inst.playid)
    end
    self:add_entity(ecs.create_entity(tpl), gizmo.target_eid, template)
end

function m:add_prefab(filename)
    local prefab_filename = filename
    if string.sub(filename,-4) == ".glb" then
        prefab_filename = filename .. "|mesh.prefab"
    end
    
    if not self.root then
        self:reset_prefab()
    end

    local parent = gizmo.target_eid or self.root
    local prefab = ecs.create_instance(prefab_filename)
    prefab.on_ready = function(inst)
        local prefab_name = gen_prefab_name()
        local v_root = create_simple_entity(prefab_name)
        ecs.method.set_parent(v_root, parent)
        self.entities[#self.entities+1] = v_root
        local children = inst.tag["*"]
        if #children == 1 then
            local child = children[1]
            w:sync("camera?in", child)
            if child.camera then
                ecs.method.set_parent(child, parent)
                local temp = serialize.parse(prefab_filename, cr.read_file(prefab_filename))
                hierarchy:add(child, {template = temp[1], editor = true, temporary = true}, parent)
                return
            end
        end
        for _, child in ipairs(children) do
            if child.scene.parent == inst.root.scene.id then
                ecs.method.set_parent(child, v_root)
            end
        end
        set_select_adapter(children, v_root)
        hierarchy:add(v_root, {filename = prefab_filename, name = prefab_name, children = children, editor = false}, parent)
    end
    function prefab:on_message(msg) end
    function prefab:on_update() end
    world:create_object(prefab)
end

function m:recreate_entity(eid)
    local prefab = hierarchy:get_template(eid)
    world:rebuild_entity(eid, prefab.template)
    
    local scale = 1
    local col = world[eid].collider
    if col then
        if col.sphere then
            scale = col.sphere[1].radius * 100
        elseif col.box then
            local size = col.box[1].size
            scale = {size[1] * 200, size[2] * 200, size[3] * 200}
        else
        end
        imaterial.set_property(eid, "u_color", {1, 0.5, 0.5, 0.5})
    end
    world:pub {"EntityRecreate", eid}
    -- return new_eid
end

function m:save_prefab(path)
    local filename
    if not path then
        if not self.prefab_filename or (string.find(self.prefab_filename, "__temp__")) then
            filename = widget_utils.get_saveas_path("Prefab", "prefab")
            if not filename then return end
        end
    end
    if path then
        filename = string.gsub(path, "\\", "/")
        local pos = string.find(filename, "%.prefab")
        if #filename > pos + 6 then
            filename = string.sub(filename, 1, pos + 6)
        end
    end
    local prefab_filename = self.prefab_filename or ""
    filename = filename or prefab_filename
    local saveas = (lfs.path(filename) ~= lfs.path(prefab_filename))

    local new_template = hierarchy:update_prefab_template(world)
    
    if not saveas then
        local path_list = split(prefab_filename)
        local glb_filename
        if #path_list > 1 then
            glb_filename = path_list[1]
        end
        if glb_filename then
            local msg = "cann't save glb file, please save as prefab"
            log.error({tag = "Editor", message = msg})
            widget_utils.message_box({title = "SaveError", info = msg})
        else
            utils.write_file(filename, stringify(new_template))
            anim_view.save_clip()
        end
        return
    end
    utils.write_file(filename, stringify(new_template))
    anim_view.save_clip(string.sub(filename, 1, -8) .. ".clips")
    self:open(filename)
    world:pub {"ResourceBrowser", "dirty"}
end

function m:remove_entity(e)
    if not e then
        return
    end
    on_remove_entity(e)
    w:remove(e)
    local index
    for idx, entity in ipairs(self.entities) do
        if entity == e then
            index = idx
            break
        end
    end
    if index then
        table.remove(self.entities, index)
    end
    hierarchy:update_slot_list(world)
    hierarchy:update_collider_list(world)
    gizmo:set_target(nil)
end

function m:get_current_filename()
    return self.prefab_filename
end

function m.set_anim_view(aview)
    anim_view = aview
end

return m