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
local camera_mgr    = ecs.require "camera_manager"
local light_gizmo   = ecs.require "gizmo.light"
local gizmo         = ecs.require "gizmo.gizmo"
local geo_utils     = ecs.require "editor.geometry_utils"
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
            scene = {srt = get_local_transform({}, parent_eid)},
            slot = true,
            follow_joint = "None",
            follow_flag = 1,
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
        transform = {t = {0, 3, 0}, r = {math.rad(130), 0, 0}},
        name = lt .. gen_light_id(),
        type = lt,
        color = {1, 1, 1, 1},
        make_shadow = false,
        intensity = 200,
        range = 1,
        motion_type = "dynamic",
        inner_radian = math.rad(45),
        outter_radian = math.rad(45)
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
                    scene = {srt = get_local_transform({s = 50}, parent_eid)},
                    filter_state = "main_view|selectable",
                    material = "/pkg/ant.resources/materials/pbr_default.material",
                    mesh = geom_mesh_file[config.type],
                    render_object = {},
                    filter_material = {},
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
        -- if type(eid) == "table" then
        --     set_select_adapter(eid, mount_root)
        -- else
            hierarchy:add_select_adapter(e, mount_root)
        --end
    end
end

local function remove_entitys(entities)
    for _, e in ipairs(entities) do
        if type(e) == "table" then
            remove_entitys(e)
        else
            w:remove(e)
        end
    end
end

local function get_prefab(filename)
    assetmgr.unload(filename)
    return worldedit:prefab_template(filename)
end

local FBXTOGLB
function m:open_fbx(filename)
    if not FBXTOGLB then
        local f = assert(lfs.open(fs.path("editor.settings"):localpath()))
        local data = f:read "a"
        f:close()
        local datalist = require "datalist"
        local settings = datalist.parse(data)
        if lfs.exists(lfs.path(settings.BlenderPath .. "/blender.exe")) then
            FBXTOGLB = subprocess.tool_exe_path(settings.BlenderPath .. "/blender")
        else
            print("Can not find blender.")
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

function m:on_prefab_ready(prefab)
    local entitys = prefab.tag["*"]
    local function find_e(entitys, id)
        for _, e in ipairs(entitys) do
            if e.scene.id == id then
                return e
            end
        end
    end

    local node_map = {}
    for i, e in ipairs(entitys) do
        node_map[e] = {template = self.prefab_template[i], parent = find_e(entitys, e.scene.parent)}
        w:sync("camera?in", e)
        if e.camera then
            camera_mgr.on_camera_ready(e)
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
        hierarchy:add(e, {template = node.template}, node.parent or self.root)
    end

    for _, e in ipairs(entitys) do
        add_to_hierarchy(e)
    end

    self.entities = entitys
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
    
    function prefab:on_message(msg)
        --print(object, msg)
    end
    
    function prefab:on_update()
        --print "update"
    end
    self.prefab_instance = world:create_object(prefab)
    world:pub {"WindowTitle", filename}
end

local function on_remove_entity(e)
    w:sync("light?in", e)
    if e.light then
        light_gizmo.on_remove_light(e)
    end
    w:sync("camera?in", e)
    if e.camera then
        camera_mgr.remove_camera(e)
    end
    -- if world[eid].skeleton_eid then
    --     w:remove(world[eid].skeleton_eid)
    -- end
    local teml = hierarchy:get_template(e)
    if teml and teml.children then
        remove_entitys(teml.children)
        -- for _, e in ipairs(teml.children) do
        --     world:remove_entity(e)
        -- end
    end
    hierarchy:del(e)
end

function m:reset_prefab()
    camera_mgr.clear()
    for _, e in ipairs(self.entities) do
        on_remove_entity(e)
        w:remove(e)
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
    -- local new_template = hierarchy:update_prefab_template()
    -- new_template[1].script = (#self.prefab_script > 0) and self.prefab_script or "/pkg/ant.prefab/default_script.lua"
    -- local prefab = utils.deep_copy(self.prefab)
    -- prefab.__class = new_template
    -- self:open_prefab(prefab)
    local filename = self.prefab_filename
    if filename == 'nil' then
        self:save_prefab(tostring(gd.project_root) .. "/res/__temp__.prefab")
    else
        self:open(filename)
    end
end

local nameidx = 0
local function gen_prefab_name() nameidx = nameidx + 1 return "prefab" .. nameidx end

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

    local parentWorldMat
    local parent
    if gizmo.target_eid then
        parent = gizmo.target_eid
        parentWorldMat = iom.worldmat(parent)
    else
        parent = self.root
        parentWorldMat = math3d.matrix{}
    end

    local s, r, t = math3d.srt(math3d.mul(math3d.inverse(parentWorldMat), math3d.matrix{}))
    
    local v_root = create_simple_entity(gen_prefab_name(), {
        r = {math3d.index(r, 1, 2, 3, 4)},
        s = {math3d.index(s, 1, 2, 3)},
        t = {math3d.index(t, 1, 2, 3)},
    })
    ecs.method.set_parent(v_root, parent)

    self.entities[#self.entities+1] = v_root
    local instance = ecs.create_instance(prefab_filename)

    ecs.method.set_parent(instance.root, v_root)
    set_select_adapter(instance.tag["*"], v_root)
    hierarchy:add(v_root, {filename = prefab_filename, children = instance.tag["*"]}, parent)
end

function m:recreate_entity(eid)
    local prefab = hierarchy:get_template(eid)
    world:rebuild_entity(eid, prefab.template)
    
    -- local copy_prefab = utils.deep_copy(prefab)
    -- local new_eid = world:deprecated_create_entity(copy_prefab.template)
    -- iom.set_srt(new_eid, iom.srt(eid))
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
    -- iom.set_scale(new_eid, scale)
    -- local new_node = hierarchy:replace(eid, new_eid)
    -- world[new_eid].parent = new_node.parent
    -- for _, v in ipairs(new_node.children) do
    --     world[v.eid].parent = new_eid
    -- end
    -- local idx
    -- for i, e in ipairs(self.entities) do
    --     if e == eid then
    --         idx = i
    --         break
    --     end
    -- end
    -- self.entities[idx] = new_eid
    -- world:remove_entity(eid)
    -- local gizmo = require "gizmo.gizmo"(world)
    -- gizmo:set_target(new_eid)
    world:pub {"EntityRecreate", eid}
    -- return new_eid
end

local utils = require "common.utils"

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