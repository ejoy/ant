local math3d 		= require "math3d"
local fs            = require "filesystem"
local lfs           = require "filesystem.local"
local vfs           = require "vfs"
local prefab_view   = require "prefab_view"
local assetmgr      = import_package "ant.asset"
local stringify     = import_package "ant.serialize".stringify
local world
local iom
local worldedit

local m = {
	entities = {}
}

function m:init(w)
	world = w
    iom = world:interface "ant.objcontroller|obj_motion"
    worldedit = import_package "ant.editor".worldedit(world)
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

function m:internal_remove(eid)
    for idx, e in ipairs(self.entities) do
        if e == eid then
            table.remove(self.entities, idx)
            return
        end
    end
end

function m:open_prefab(filename)
	if self.entities then
        for _, eid in ipairs(self.entities) do
            local teml = prefab_view:get_template(eid)
            if teml.children then
                for _, e in ipairs(teml.children) do
                    world:remove_entity(e)
                end
            end
            world:remove_entity(eid)
		end
    end
    local vfspath = tostring(lfs.relative(lfs.path(filename), fs.path "":localpath()))
    local prefab = worldedit:prefab_template(vfspath)
    local entities = worldedit:prefab_instance(prefab)
    local root = entities[1]
    prefab_view:clear()
    prefab_view:set_root(root)
    prefab_view.root.template.template = prefab.__class[1]
    local tp = prefab_view:get_template(root)
    tp.prefab = prefab
    --worldedit:prefab_set(prefab, "/3/data/state", worldedit:prefab_get(prefab, "/3/data/state") & ~1)
    --worldedit:prefab_set(prefab, "/1/data/material", worldedit:prefab_get(prefab, "/3/data/state") & ~1)
    --worldedit:prefab_set(prefab, "/4/action/mount", 1)
    local remove_entity = {}
    for i, entity in ipairs(entities) do
        if type(entity) == "table" then            
            local parent = world[entity[1]].parent
            local teml = prefab_view:get_template(parent)
            teml.filename = prefab.__class[i].prefab
            teml.children = entity
            for _, e in ipairs(entity) do
                prefab_view:add_select_adapter(e, parent)
            end
            remove_entity[#remove_entity+1] = entity
        else
            if world[entity].parent then
                prefab_view:add(entity, {template = prefab.__class[i]}, world[entity].parent)
            end
        end
    end

	self.root = root
	self.prefab = prefab
    self.entities = entities
    
    for _, e in ipairs(remove_entity) do
        self:internal_remove(e)
    end

	--self:normalize_aabb()
    world:pub {"editor", "prefab", entities}
    world:pub {"WindowTitle", filename}
end

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
    local entity_name = "Prefab_" .. mount_root
    entity_template.data.name = entity_name
    world[mount_root].name = entity_name
    local vfspath = tostring(lfs.relative(lfs.path(filename), fs.path "":localpath()))
    local prefab = worldedit:prefab_template(vfspath)
    local entities = worldedit:prefab_instance(prefab)
    world[entities[1]].parent = mount_root
    for i, e in ipairs(entities) do
        prefab_view:add_select_adapter(e, mount_root)
    end

    local current_dir = lfs.path(tostring(self.prefab)):parent_path()
    local relative_path = lfs.relative(lfs.path(vfspath), current_dir)

    prefab_view:add(mount_root, {template = entity_template, filename = tostring(relative_path), children = entities}, self.root)
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
    local self_prefab = tostring(self.prefab) --tostring(fs.path "":localpath()) .. tostring(self.prefab)
    filename = filename or self_prefab
    local saveas = (lfs.path(filename) ~= lfs.path(self_prefab))
    prefab_view:update_prefab_template(assetmgr.edit(self.prefab))
    self.entities.__class = self.prefab.__class
    if not saveas then
        write_file(filename, stringify(self.entities.__class))
        return
    end
    local data = self.entities.__class
    local current_dir = lfs.path(self_prefab):parent_path()
    local new_dir = lfs.path(filename):localpath():parent_path()
    if current_dir ~= new_dir then
        --data = utils.deep_copy(self.entities.__class)
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
    local teml = prefab_view:get_template(eid)
    if teml.children then
        for _, e in ipairs(teml.children) do
            world:remove_entity(e)
        end
        -- local child_idx = find_index(self.entities, teml.children)
        -- if child_idx then
        --     table.remove(self.entities, child_idx)
        -- end
        self:internal_remove(teml.children)
    end
    world:remove_entity(eid)
    -- local eid_index = find_index(self.entities, eid)
    -- table.remove(self.entities, eid_index)
    self:internal_remove(eid)
    prefab_view:del(eid)
end

function m:get_current_filename()
    return tostring(self.prefab)
end

return m