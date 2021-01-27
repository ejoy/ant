local math3d 		= require "math3d"
local fs            = require "filesystem"
local lfs           = require "filesystem.local"
local vfs           = require "vfs"
local hierarchy     = require "hierarchy"
local assetmgr      = import_package "ant.asset"
local stringify     = import_package "ant.serialize".stringify
local widget_utils  = require "widget.utils"
local bgfx          = require "bgfx"
local gd            = require "common.global_data"
local utils         = require "common.utils"
local geo_utils
local logger
local ilight
local light_gizmo
local gizmo
local camera_mgr
local world
local iom
local worldedit
local m = {
    entities = {}
}
local aabb_color_i = 0x6060ffff
local aabb_color = {1.0, 0.38, 0.38, 1.0}
local highlight_aabb_eid
function m:update_current_aabb(eid)
    if not highlight_aabb_eid then
        highlight_aabb_eid = geo_utils.create_dynamic_aabb({}, "highlight_aabb")
        imaterial.set_property(highlight_aabb_eid, "u_color", aabb_color)
        ies.set_state(highlight_aabb_eid, "auxgeom", true)
    end
    ies.set_state(highlight_aabb_eid, "visible", false)
    if not eid or world[eid].camera or world[eid].light_type then
        return
    end
    local aabb = nil
    local e = world[eid]
    if e.mesh and e.mesh.bounding then
        local w = iom.calc_worldmat(eid)
        aabb = math3d.aabb_transform(w, e.mesh.bounding.aabb)
    else
        local adaptee = hierarchy:get_select_adaptee(eid)
        for _, eid in ipairs(adaptee) do
            local e = world[eid]
            if e.mesh and e.mesh.bounding then
                local newaabb = math3d.aabb_transform(iom.calc_worldmat(eid), e.mesh.bounding.aabb)
                aabb = aabb and math3d.aabb_merge(aabb, newaabb) or newaabb
            end
        end
    end

    if aabb then
        local v = math3d.tovalue(aabb)
        local aabb_shape = {min={v[1],v[2],v[3]}, max={v[5],v[6],v[7]}}
        local vb, ib = geo_utils.get_aabb_vb_ib(aabb_shape, aabb_color_i)
        local rc = world[highlight_aabb_eid]._rendercache
        local vbdesc, ibdesc = rc.vb, rc.ib
        bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", vb))
        ies.set_state(highlight_aabb_eid, "visible", true)
    end
end

function m:normalize_aabb()
    local aabb
    for _, eid in ipairs(self.entities) do
        local e = world[eid]
        if e.mesh and e.mesh.bounding then
            local newaabb = math3d.aabb_transform(iom.calc_worldmat(eid), e.mesh.bounding.aabb)
            aabb = aabb and math3d.aabb_merge(aabb, newaabb) or newaabb
        end
    end

    if not aabb then return end

    local aabb_mat = math3d.tovalue(aabb)
    local min_x, min_y, min_z = aabb_mat[1], aabb_mat[2], aabb_mat[3]
    local max_x, max_y, max_z = aabb_mat[5], aabb_mat[6], aabb_mat[7]
    local s = 1/math.max(max_x - min_x, max_y - min_y, max_z - min_z)
    local t = {-(max_x+min_x)/2,-min_y,-(max_z+min_z)/2}
    local transform = math3d.mul(math3d.matrix{ s = s }, { t = t })
    iom.set_srt(self.root, math3d.mul(transform, iom.srt(self.root)))
end

local recorderidx = 0
local function gen_camera_recorder_name() recorderidx = recorderidx + 1 return "recorder" .. recorderidx end

local lightidx = 0
local function gen_light_id() lightidx = lightidx + 1 return lightidx end

local geometricidx = 0
local function gen_light_id() geometricidx = geometricidx + 1 return geometricidx end

local function create_light_billboard(light_eid)
    local bb_eid = world:create_entity{
        policy = {
            "ant.render|render",
            "ant.effect|billboard",
            "ant.general|name"
        },
        data = {
            name = "billboard_light",
            transform = {},
            billboard = {lock = "camera"},
            state = 1,
            scene_entity = true,
            material = gd.package_path .. "res/materials/billboard.material"
        },
        action = {
            bind_billboard_camera = "camera"
        }
    }
    local icons = require "common.icons"(assetmgr)
    local tex
    local light_type = world[light_eid].light_type
    if light_type == "spot" then
        tex = icons.ICON_SPOTLIGHT.handle
    elseif light_type == "point" then
        tex = icons.ICON_POINTLIGHT.handle
    elseif light_type == "directional" then
        tex = icons.ICON_DIRECTIONALLIGHT.handle
        ilight.active_directional_light(light_eid)
    end
    imaterial.set_property(bb_eid, "s_basecolor", {stage = 0, texture = {handle = tex}})
    iom.set_scale(bb_eid, 0.2)
    ies.set_state(bb_eid, "auxgeom", true)
    iom.set_position(bb_eid, iom.get_position(light_eid))
    world[bb_eid].parent = world[light_eid].parent
    light_gizmo.billboard[light_eid] = bb_eid
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

local slot_entity_id = 1
function m:create_slot()
    if not gizmo.target_eid then return end
    local new_entity, temp = world:create_entity {
        action = { mount = 0 },
        policy = {
            "ant.general|name",
            "ant.scene|slot_policy",
            "ant.scene|transform_policy",
        },
        data = {
            transform = {},
            slot = true,
            follow_flag = 1,
            name = "empty" .. slot_entity_id,
        }
    }
    slot_entity_id = slot_entity_id + 1
    world[new_entity].parent = gizmo.target_eid
    self.entities[#self.entities+1] = new_entity
    hierarchy:add(new_entity, {template = temp.__class[1]}, gizmo.target_eid)
    hierarchy:update_slot_list()
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
    
    local new_entity, temp = world:create_entity {
        action = { mount = 0 },
        policy = {
            "ant.general|name",
            "ant.render|render",
            "ant.scene|hierarchy_policy",
            "ant.scene|transform_policy",
            "ant.collision|collider_policy"
        },
        data = {
            name = "collider" .. geometricidx,
            scene_entity = true,
            transform = {s = scale},
            collider = { [config.type] = define },
            color = {1, 0.5, 0.5, 0.5},
            state = ies.create_state "visible|selectable",
            material = "/pkg/ant.resources/materials/singlecolor.material",
            mesh = (config.type == "box") and geom_mesh_file["cube"] or geom_mesh_file[config.type]
        }
    }
    imaterial.set_property(new_entity, "u_color", {1, 0.5, 0.5, 0.5})
    return new_entity, temp
end

function m:create(what, config)
    if not self.root then
        self:reset_prefab()
    end
    if what == "slot" then
        self:create_slot()
    elseif what == "camera" then
        local new_camera, camera_templ = camera_mgr.ceate_camera()
        local s, r, t = math3d.srt(camera_templ.data.transform)
        local ts, tr, tt = math3d.totable(s), math3d.totable(r), math3d.totable(t)
        camera_templ.data.transform = {s = {ts[1],ts[2],ts[3]}, r = {tr[1],tr[2],tr[3],tr[4]}, t = {tt[1],tt[2],tt[3]}}

        local recorder, recorder_templ = icamera_recorder.start(gen_camera_recorder_name())
        camera_mgr.bind_recorder(new_camera, recorder)
        camera_mgr.add_recorder_frame(new_camera)
        local node = hierarchy:add(new_camera, {template = camera_templ, keyframe = recorder_templ.__class[1]}, self.root)
        node.camera = true
        self.entities[#self.entities+1] = new_camera
    elseif what == "geometry" then
        if config.type == "cube"
            or config.type == "cone"
            or config.type == "cylinder"
            or config.type == "sphere"
            or config.type == "torus" then
            local new_entity, temp = world:create_entity {
                action = { mount = 0 },
                policy = {
                    "ant.render|render",
                    "ant.general|name",
                    "ant.scene|hierarchy_policy",
                },
                data = {
                    color = {1, 1, 1, 1},
                    scene_entity = true,
                    state = ies.create_state "visible|selectable",
                    transform = {s = 50},
                    material = "/pkg/ant.resources/materials/singlecolor.material",
                    mesh = geom_mesh_file[config.type],
                    name = config.type .. geometricidx
                }
            }
            imaterial.set_property(new_entity, "u_color", {1, 1, 1, 1})
            world[new_entity].parent = gizmo.target_eid or self.root
            self.entities[#self.entities+1] = new_entity
            hierarchy:add(new_entity, {template = temp.__class[1]}, world[new_entity].parent)
        elseif config.type == "cube(prefab)" then
            m:add_prefab(gd.package_path .. "res/cube.prefab")
        elseif config.type == "cone(prefab)" then
            m:add_prefab(gd.package_path .. "res/cone.prefab")
        elseif config.type == "cylinder(prefab)" then
            m:add_prefab(gd.package_path .. "res/cylinder.prefab")
        elseif config.type == "sphere(prefab)" then
            m:add_prefab(gd.package_path .. "res/sphere.prefab")
        elseif config.type == "torus(prefab)" then
            m:add_prefab(gd.package_path .. "res/torus.prefab")
        end
    elseif what == "light" then
        if config.type == "directional" or config.type == "point" or config.type == "spot" then      
            local ilight = world:interface "ant.render|light" 
            local _, newlight = ilight.create({
                transform = {},
                name = config.type .. gen_light_id(),
                light_type = config.type,
                color = {1, 1, 1, 1},
                intensity = 2,
                range = 1,
                radian = math.rad(45)
            })
            local new_light = newlight[1]
            self.entities[#self.entities+1] = new_light
            hierarchy:add(new_light, {template = newlight.__class[1]}, self.root)
            create_light_billboard(new_light)
        end
    elseif what == "collider" then
        local new_entity, temp = self:create_collider(config)
        world[new_entity].parent = gizmo.target_eid or self.root
        self.entities[#self.entities+1] = new_entity
        if config.add_to_hierarchy then
            hierarchy:add(new_entity, {template = temp.__class[1]}, world[new_entity].parent)
        end
    end
end

function m:internal_remove(eid)
    for idx, e in ipairs(self.entities) do
        if e == eid then
            table.remove(self.entities, idx)
            return
        end
    end
end

local function set_select_adapter(entity_set, mount_root)
    for _, eid in ipairs(entity_set) do
        if type(eid) == "table" then
            set_select_adapter(eid, mount_root)
        else
            hierarchy:add_select_adapter(eid, mount_root)
        end
    end
end

local function remove_entitys(entities)
    for _, eid in ipairs(entities) do
        if type(eid) == "table" then
            remove_entitys(eid)
        else
            world:remove_entity(eid)
        end
    end
end

local function get_prefab(filename)
    --local vfspath = tostring(lfs.relative(lfs.path(filename), fs.path "":localpath()))
    assetmgr.unload(filename)
    return worldedit:prefab_template(filename)
end

function m:open(filename)
    local prefab = get_prefab(filename)--get_prefab("/pkg/tools.prefab_editor/res/fire.prefab")--
    self:open_prefab(prefab)
    world:pub {"WindowTitle", filename}
end

local function create_simple_entity(name)
    return world:create_entity{
		policy = {
            "ant.general|name",
            "ant.scene|hierarchy_policy",
            "ant.scene|transform_policy"
		},
		data = {
            name = name,
            scene_entity = true,
            transform = {}
		},
    }
end

function m:reset_prefab()
    camera_mgr.clear()
    for _, eid in ipairs(self.entities) do
        if type(eid) == "table" then
            assert(false)
        end
        local teml = hierarchy:get_template(eid)
        if teml and teml.children then
            remove_entitys(teml.children)
        end
        world:remove_entity(eid)
    end
    light_gizmo.clear()
    hierarchy:clear()
    self.root = create_simple_entity("scene root")
    hierarchy:set_root(self.root)
end

function m:open_prefab(prefab)
    self:reset_prefab()
    self.prefab = prefab
    local entities = worldedit:prefab_instance(prefab)
    self.entities = entities
    local remove_entity = {}
    local add_entity = {}
    local last_camera
    for i, entity in ipairs(entities) do
        if type(entity) == "table" then          
            -- entity[1] : root node  
            local parent = world[entity[1]].parent
            if parent then
                local teml = hierarchy:get_template(parent)
                teml.filename = prefab.__class[i].prefab
                teml.children = entity
                set_select_adapter(entity, parent)
            else
                local prefab_root = create_simple_entity("prefab" .. i)
                hierarchy:add(prefab_root, {filename = prefab.__class[i].prefab, children = entity}, self.root)
                for _, e in ipairs(entity) do
                    if not world[e].parent then
                        world[e].parent = prefab_root
                    end
                end
                add_entity[#add_entity+1] = prefab_root
            end
            remove_entity[#remove_entity+1] = entity
        else
            local keyframes = prefab.__class[i].data.frames
            if keyframes and last_camera then
                for i, v in ipairs(keyframes) do
                    local tp = v.position
                    local tr = v.rotation
                    v.position = math3d.ref(math3d.vector(tp[1], tp[2], tp[3]))
                    v.rotation = math3d.ref(math3d.quaternion(tr[1], tr[2], tr[3], tr[4]))
                end

                local templ = hierarchy:get_template(last_camera)
                templ.keyframe = prefab.__class[i]
                camera_mgr.bind_recorder(last_camera, entity)
                remove_entity[#remove_entity+1] = entity
            else
                if world[entity].collider then
                    local collider = world[entity].collider
                    local config = {}
                    if collider.sphere then
                        config.type = "sphere"
                        config.define = collider.sphere
                    elseif collider.box then
                        config.type = "box"
                        config.define = collider.box
                    end
                    local new_entity, temp = self:create_collider(config)
                    
                    if world[entity].parent and world[world[entity].parent].slot then
                        world[new_entity].slot_name = world[world[entity].parent].name
                    end
                    world[new_entity].parent = world[entity].parent or self.root
                    hierarchy:add(new_entity, {template = temp.__class[1]}, world[new_entity].parent)
                    add_entity[#add_entity + 1] = new_entity
                    remove_entity[#remove_entity+1] = entity
                else
                    hierarchy:add(entity, {template = prefab.__class[i]}, world[entity].parent or self.root)
                end
            end
            if world[entity].camera then
                camera_mgr.update_frustrum(entity)
                camera_mgr.show_frustum(entity, false)
                last_camera = entity
            elseif world[entity].light_type then
                create_light_billboard(entity)
                light_gizmo.bind(entity)
                light_gizmo.show(false)
            elseif world[entity].collider then
                world:remove_entity(entity)
            end
        end
    end
    for _, e in ipairs(remove_entity) do
        self:internal_remove(e)
    end
    for _, e in ipairs(add_entity) do
        self.entities[#self.entities + 1] = e
    end
    world:pub {"editor", "prefab", entities}
end

local nameidx = 0
local function gen_prefab_name() nameidx = nameidx + 1 return "prefab" .. nameidx end

function m:add_prefab(filename)
    if not self.root then
        self:reset_prefab()
    end
    -- local entity_template = {
    --     action = {
    --         mount = 1
    --     },
    --     policy = {
    --         "ant.general|name",
    --         "ant.scene|transform_policy"
    --     },
    --     data = {
    --         name = gen_prefab_name(),
    --         transform = {},
    --         scene_entity = true
    --     }
    -- }
    local mount_root = create_simple_entity(gen_prefab_name())--world:create_entity(entity_template)
    self.entities[#self.entities+1] = mount_root
    -- entity_template.data.name = entity_name
    -- world[mount_root].name = entity_name
    local prefab = worldedit:prefab_template(filename)
    local entities = worldedit:prefab_instance(prefab)
    world[entities[1]].parent = mount_root
    
    set_select_adapter(entities, mount_root)
    --hierarchy:add(mount_root, {template = entity_template, filename = filename, children = entities}, self.root)
    hierarchy:add(mount_root, {filename = filename, children = entities}, self.root)
end

function m:recreate_entity(eid)
    local prefab = hierarchy:get_template(eid)
    local copy_prefab = utils.deep_copy(prefab)
    local new_eid = world:create_entity(copy_prefab.template)
    iom.set_srt(new_eid, iom.srt(eid))
    local scale = 1
    if world[new_eid].collider.sphere then
        scale = world[new_eid].collider.sphere[1].radius * 100
    elseif world[new_eid].collider.box then
        local size = world[new_eid].collider.box[1].size
        scale = {size[1] * 200, size[2] * 200, size[3] * 200}
    else
    end
    iom.set_scale(new_eid, scale)
    if world[new_eid].collider then
        imaterial.set_property(new_eid, "u_color", {1, 0.5, 0.5, 0.5})
    end

    --world[new_eid].name = world[eid].name
    local new_node = hierarchy:replace(eid, new_eid)
    world[new_eid].parent = new_node.parent
    for _, v in ipairs(new_node.children) do
        world[v.eid].parent = new_eid
    end
    local idx
    for i, e in ipairs(self.entities) do
        if e == eid then
            idx = i
            break
        end
    end
    self.entities[idx] = new_eid
    world:remove_entity(eid)
    local gizmo = require "gizmo.gizmo"(world)
    gizmo:set_target(new_eid)
    return new_eid
end

function m:update_material(eid, mtl)
    local prefab = hierarchy:get_template(eid)
    prefab.template.data.material = mtl
    return self:recreate_entity(eid)
end

local utils = require "common.utils"

local function split(str)
    local r = {}
    str:gsub('[^|]*', function (w) r[#r+1] = w end)
    return r
end

local function get_filename(pathname)
    pathname = pathname:lower()
    return pathname:match "[/]?([^/]*)$"
end

local function convert_path(path, current_dir, new_dir, glb_filename)
    if fs.path(path):is_absolute() then return path end
    local new_path
    if glb_filename then
        local dir = tostring(lfs.relative(current_dir, new_dir)) .. "/" .. glb_filename
        local pretty = tostring(lfs.path(path))
        if string.sub(path, 1, 2) == "./" then
            pretty = string.sub(path, 3)
        end
        new_path = dir .. "|" .. pretty
    else
        local op_path = path
        local spec = string.find(path, '|')
        if spec then
            op_path = string.sub(path, 1, spec - 1)
        end
        new_path = tostring(lfs.relative(current_dir / lfs.path(op_path), new_dir))
        if spec then
            new_path = new_path .. string.sub(path, spec)
        end
    end
    return new_path
end

function m:save_prefab(path)
    local filename
    if not self.prefab and not path then
        filename = widget_utils.get_saveas_path("Prefab", ".prefab")
        if not filename then return end
    end
    if path then
        filename = string.gsub(path, "\\", "/")
        local pos = string.find(filename, "%.prefab")
        if #filename > pos + 6 then
            filename = string.sub(filename, 1, pos + 6)
        end
    end
    local prefab_filename = self.prefab and tostring(self.prefab) or ""
    filename = filename or prefab_filename
    local saveas = (lfs.path(filename) ~= lfs.path(prefab_filename))
    local current_templ = hierarchy:update_prefab_template()
    -- if self.prefab then
    --     self.prefab.__class = current_templ
    -- end
    self.entities.__class = current_templ
    
    local path_list = split(prefab_filename)
    local glb_filename
    if #path_list > 1 then
        glb_filename = get_filename(path_list[1])
    end

    if not saveas then
        if glb_filename then
            local msg = "cann't save glb file, please save as prefab"
            logger.error({tag = "Editor", message = msg})
            widget_utils.message_box({title = "SaveError", info = msg})
        else
            utils.write_file(filename, stringify(self.entities.__class))
        end
        return
    end
    local data = self.entities.__class
    local current_dir = lfs.path(prefab_filename):parent_path()
    local new_dir = lfs.path(filename):localpath():parent_path()
    for _, t in ipairs(data) do
        if t.prefab then
            t.prefab = convert_path(t.prefab, current_dir, new_dir, glb_filename)
        else
            if t.data.material then
                t.data.material = convert_path(t.data.material, current_dir, new_dir, glb_filename)
            end
            if t.data.mesh then
                t.data.mesh = convert_path(t.data.mesh, current_dir, new_dir, glb_filename)
            end
            if t.data.meshskin then
                t.data.meshskin = convert_path(t.data.meshskin, current_dir, new_dir, glb_filename)
            end
            if t.data.skeleton then
                t.data.skeleton = convert_path(t.data.skeleton, current_dir, new_dir, glb_filename)
            end
            if t.data.animation then
                local animation = t.data.animation
                for k, v in pairs(t.data.animation) do
                    animation[k] = convert_path(v, current_dir, new_dir, glb_filename)
                end
            end
        end
    end
    utils.write_file(filename, stringify(data))
    self:open(filename)
    world:pub {"ResourceBrowser", "dirty"}
end

function m:remove_entity(eid)
    if not eid then return end
    if world[eid].camera then
        camera_mgr.remove_camera(eid)
    elseif world[eid].light_type then
        light_gizmo.on_remove_light(eid)
    end
    if world[eid].skeleton_eid then
        world:remove_entity(world[eid].skeleton_eid)
    end
    local teml = hierarchy:get_template(eid)
    if teml and teml.children then
        for _, e in ipairs(teml.children) do
            world:remove_entity(e)
        end
    end
    world:remove_entity(eid)
    hierarchy:del(eid)
    self:internal_remove(eid)
end

function m:get_current_filename()
    return tostring(self.prefab)
end

return function(w)
    world       = w
    camera_mgr  = require "camera_manager"(world)
    iom         = world:interface "ant.objcontroller|obj_motion"
    worldedit   = import_package "ant.editor".worldedit(world)
    ilight      = world:interface "ant.render|light"
    light_gizmo = require "gizmo.light"(world)
    gizmo = require "gizmo.gizmo"(world)
    geo_utils   = require "editor.geometry_utils"(world)
    local asset_mgr = import_package "ant.asset"
    logger      = require "widget.log"(asset_mgr)
    return m
end