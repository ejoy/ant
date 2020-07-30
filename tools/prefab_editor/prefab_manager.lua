local math3d 		= require "math3d"
local fs            = require "filesystem"
local lfs           = require "filesystem.local"
local prefab_view   = require "prefab_view"

local world
local iom
local worldedit

local m = {
	entities = {}
}

function m:init(w)
	world = w
	iom = world:interface "ant.objcontroller|obj_motion"
	worldedit = require "worldedit"(world)
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

function m:open_prefab(filename)
	if self.root then world:remove_entity(self.root) end
	if self.entities then
		for _, eid in ipairs(self.entities) do
			world:remove_entity(eid)
		end
	end
    local root = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|transform_policy",
        },
        data = {
            name = "Root",
            transform = {},
            scene_entity = true
        }
	}
	prefab_view:clear()
    prefab_view:set_root(root)
    local prefab = worldedit:prefab_template(filename)
    local entities = worldedit:prefab_instance(prefab, {root = root})
    --worldedit:prefab_set(prefab, "/3/data/state", worldedit:prefab_get(prefab, "/3/data/state") & ~1)
    --worldedit:prefab_set(prefab, "/1/data/material", worldedit:prefab_get(prefab, "/3/data/state") & ~1)
    --worldedit:prefab_set(prefab, "/4/action/mount", 1)
    for i, e in ipairs(entities) do
        prefab_view:add(e, {prefab = prefab}, world[e].parent)
	end
	self.root = root
	self.prefab = prefab
	self.entities = entities
	self:normalize_aabb()
	world:pub {"editor", "prefab", entities}
end

function m:add_prefab(filename)
	local root = world:create_entity {
        policy = {
            "ant.general|name",
            "ant.scene|transform_policy",
        },
        data = {
            name = "",
            transform = {},
            scene_entity = true
        }
	}

	world[root].name = "prefab_" .. root

	local prefab = worldedit:prefab_template(filename)
	local entities = worldedit:prefab_instance(prefab, {root = root})
    local relative_path = lfs.relative(lfs.path(filename), fs.path "":localpath())
    prefab_view:add(root, {prefab = prefab, filename = relative_path}, self.root)
end

local fs = require "filesystem"
local lfs = require "filesystem.local"

local function write_file(filename, data)
    local f = assert(lfs.open(fs.path(filename):localpath(), "wb"))
    f:write(data)
    f:close()
end

function m:save_prefab(filename)
    lfs.create_directories(fs.path(filename):localpath():parent_path())

    write_file(filename, world:serialize(self.entities, {{mount="root"}}))
    -- local stringify = import_package "ant.serialize".stringify
    -- local e = world[entities[3]]
    -- write_file('/pkg/tools.viewer.prefab_viewer/res/root/test.material', stringify(e.material))
end

-- local eventSerializePrefab = world:sub {"serialize_prefab"}

-- function m:data_changed()
--     for _, filename in eventSerializePrefab:unpack() do
--         serializePrefab(filename)
--     end
-- end

return m