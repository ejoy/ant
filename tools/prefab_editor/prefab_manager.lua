local math3d 		= require "math3d"
local fs            = require "filesystem"
local lfs           = require "filesystem.local"
local vfs           = require "vfs"
local hierarchy   = require "hierarchy"
local assetmgr      = import_package "ant.asset"
local stringify     = import_package "ant.serialize".stringify
local light_gizmo
local camera_mgr
local world
local iom
local worldedit
local m = {
	entities = {}
}

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

function m:create(what)
    local localpath = tostring(fs.path "":localpath())
    if what == "camera" then
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
    elseif what == "camerarecorder" then
        -- local recorder, templ = camera_mgr.ceate_camera_recorder()
        -- local node = hierarchy:add(new_camera, {template = templ}, self.root)
        -- node.camera_recorder = true
    elseif what == "empty" then

    elseif what == "cube" then
        m:add_prefab(localpath .. "res/cube.prefab")
    elseif what == "cone" then
        m:add_prefab(localpath .. "res/cone.prefab")
    elseif what == "cylinder" then
        m:add_prefab(localpath .. "res/cylinder.prefab")
    elseif what == "sphere" then
        m:add_prefab(localpath .. "res/sphere.prefab")
    elseif what == "torus" then
        m:add_prefab(localpath .. "res/torus.prefab")
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

function m:open_prefab(filename)
    camera_mgr.clear()
    for _, eid in ipairs(self.entities) do
        local teml = hierarchy:get_template(eid)
        if teml and teml.children then
            for _, e in ipairs(teml.children) do
                world:remove_entity(e)
            end
        end
        world:remove_entity(eid)
    end
    light_gizmo.reset()

    local vfspath = tostring(lfs.relative(lfs.path(filename), fs.path "":localpath()))
    assetmgr.unload(vfspath)

    local prefab = worldedit:prefab_template(vfspath)
    self.prefab = prefab
    local entities = worldedit:prefab_instance(prefab)
    self.entities = entities

    local scene_root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {},
			name = "scene root",
		},
    }
    self.root = scene_root
    --self.root = entities[1]
    hierarchy:clear()
    hierarchy:set_root(self.root)
    --hierarchy.root.template.template = prefab.__class[1]

    --worldedit:prefab_set(prefab, "/3/data/state", worldedit:prefab_get(prefab, "/3/data/state") & ~1)
    --worldedit:prefab_set(prefab, "/1/data/material", worldedit:prefab_get(prefab, "/3/data/state") & ~1)
    --worldedit:prefab_set(prefab, "/4/action/mount", 1)
    local remove_entity = {}
    local last_camera
    for i, entity in ipairs(entities) do
        if type(entity) == "table" then          
            -- entity[1] : root node  
            local parent = world[entity[1]].parent
            if parent then
                local teml = hierarchy:get_template(parent)
                teml.filename = prefab.__class[i].prefab
                teml.children = entity
                for _, e in ipairs(entity) do
                    hierarchy:add_select_adapter(e, parent)
                end
                remove_entity[#remove_entity+1] = entity
            else
                -- local prefab_root = world:create_entity{
                --     policy = {
                --         "ant.general|name",
                --         "ant.scene|transform_policy",
                --     },
                --     data = {
                --         transform = {},
                --         name = "prefab" .. i,
                --     },
                -- }
                -- hierarchy:add(prefab_root, {filename = prefab.__class[i].prefab}, self.root)
            end
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
                hierarchy:add(entity, {template = prefab.__class[i]}, world[entity].parent or self.root)
            end
            if world[entity].camera then
                camera_mgr.update_frustrum(entity)
                camera_mgr.show_frustum(entity, false)
                last_camera = entity
            end
            if world[entity].light_type == "directional" then
                light_gizmo.bind(entity)
            end
        end
    end
    for _, e in ipairs(remove_entity) do
        self:internal_remove(e)
    end

	--self:normalize_aabb()
    world:pub {"editor", "prefab", entities}
    world:pub {"WindowTitle", filename}
end

local nameidx = 0
local function gen_prefab_name() nameidx = nameidx + 1 return "prefab" .. nameidx end

function m:add_prefab(filename)
    local entity_template = {
        action = {
            mount = 1
        },
        policy = {
            "ant.general|name",
            "ant.scene|transform_policy"
        },
        data = {
            name = "",
            transform = {},
            scene_entity = true
        }
    }
    local mount_root = world:create_entity(entity_template)
    self.entities[#self.entities+1] = mount_root
    local entity_name = gen_prefab_name()
    entity_template.data.name = entity_name
    world[mount_root].name = entity_name
    local vfspath = tostring(lfs.relative(lfs.path(filename), fs.path "":localpath()))
    local prefab = worldedit:prefab_template(vfspath)
    local entities = worldedit:prefab_instance(prefab)
    world[entities[1]].parent = mount_root
    for i, e in ipairs(entities) do
        hierarchy:add_select_adapter(e, mount_root)
    end

    local current_dir = lfs.path(tostring(self.prefab)):parent_path()
    local relative_path = lfs.relative(lfs.path(vfspath), current_dir)

    hierarchy:add(mount_root, {template = entity_template, filename = tostring(relative_path), children = entities}, self.root)
end

local fs = require "filesystem"
local lfs = require "filesystem.local"

local function write_file(filename, data)
    local f = assert(lfs.open(fs.path(filename):localpath(), "wb"))
    f:write(data)
    f:close()
end

local utils = require "common.utils"

local function convert_path(path, current_dir, new_dir)
    if fs.path(path):is_absolute() then return path end
    local op_path = path
    local spec = string.find(path, '|')
    if spec then
        op_path = string.sub(path, 1, spec - 1)
    end
    local new_path = tostring(lfs.relative(current_dir / lfs.path(op_path), new_dir))
    if spec then
        new_path = new_path .. string.sub(path, spec)
    end
    return new_path
end

function m:save_prefab(filename)
    if not self.prefab then return end
    if filename then
        filename = string.gsub(filename, "\\", "/")
        local pos = string.find(filename, "%.prefab")
        if #filename > pos + 6 then
            filename = string.sub(filename, 1, pos + 6)
        end
        filename = tostring(lfs.relative(lfs.path(filename), fs.path "":localpath()))
    end
    local prefab_filename = tostring(self.prefab)
    filename = filename or prefab_filename
    local saveas = (lfs.path(filename) ~= lfs.path(prefab_filename))
    hierarchy:update_prefab_template(assetmgr.edit(self.prefab))
    self.entities.__class = self.prefab.__class
    if not saveas then
        write_file(filename, stringify(self.entities.__class))
        return
    end
    local data = self.entities.__class
    local current_dir = lfs.path(prefab_filename):parent_path()
    local new_dir = lfs.path(filename):localpath():parent_path()
    if current_dir ~= new_dir then
        for _, t in ipairs(data) do
            if t.prefab then
                t.prefab = convert_path(t.prefab, current_dir, new_dir)
            else
                if t.data.material then
                    t.data.material = convert_path(t.data.material, current_dir, new_dir)
                end
                if t.data.mesh then
                    t.data.mesh = convert_path(t.data.mesh, current_dir, new_dir)
                end
                if t.data.meshskin then
                    t.data.meshskin = convert_path(t.data.meshskin, current_dir, new_dir)
                end
                if t.data.skeleton then
                    t.data.skeleton = convert_path(t.data.skeleton, current_dir, new_dir)
                end
                if t.data.animation then
                    local animation = t.data.animation
                    for k, v in pairs(t.data.animation) do
                        animation[k] = convert_path(v, current_dir, new_dir)
                    end
                end
            end
        end
    end
    write_file(filename, stringify(data))
    self:open_prefab(tostring(fs.path "":localpath()) .. filename)
    world:pub {"ResourceBrowser", "dirty"}
end

function m:remove_entity(eid)
    if not eid then return end
    if world[eid].camera then
        camera_mgr.remove_camera(eid)
    end
    local teml = hierarchy:get_template(eid)
    if teml.children then
        for _, e in ipairs(teml.children) do
            world:remove_entity(e)
        end
    end
    world:remove_entity(eid)
    self:internal_remove(eid)
    hierarchy:del(eid)
end

function m:get_current_filename()
    return tostring(self.prefab)
end

return function(w)
    world       = w
    camera_mgr  = require "camera_manager"(world)
    iom         = world:interface "ant.objcontroller|obj_motion"
    worldedit   = import_package "ant.editor".worldedit(world)
    light_gizmo = require "gizmo.directional_light"(world)
    return m
end