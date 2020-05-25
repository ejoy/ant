local ecs = ...
local world = ecs.world

local fs = require "filesystem"

local renderpkg  = import_package 'ant.render'
local math3d  = require 'math3d'

local eventResetPrefab = world:sub {"reset_prefab"}

local m = ecs.system 'init_system'

local entities = {}
local function createPrefab(filename)
    for _, eid in ipairs(entities) do
        world:remove_entity(eid)
    end
    entities = world:instance(filename, {root=0})
    world:pub {"editor", "prefab", entities}
    local aabb
    for _, eid in ipairs(entities) do
        local e = world[eid]
        if e.mesh and e.mesh.bounding then
            local newaabb = math3d.aabb_transform(e.transform.srt, e.mesh.bounding.aabb)
            aabb = aabb and math3d.aabb_merge(aabb, newaabb) or newaabb
        end
    end
    local aabb_mat = math3d.tovalue(aabb)
    local min_x, min_y, min_z = aabb_mat[1], aabb_mat[2], aabb_mat[3]
    local max_x, max_y, max_z = aabb_mat[5], aabb_mat[6], aabb_mat[7]
    local s = 1/math.max(max_x - min_x, max_y - min_y, max_z - min_z)
    local t = {-(max_x+min_x)/2,-min_y,-(max_z+min_z)/2}
    local transform = math3d.mul(math3d.matrix{ s = s }, { t = t })
    for _, eid in ipairs(entities) do
        local e = world[eid]
        if e.transform then
            e.transform.srt.m = math3d.mul(transform, e.transform.srt)
        end
    end
end

function m:init()
    renderpkg.components.create_grid_entity(world, "", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
    world:instance '/pkg/tools.viewer.prefab_viewer/light_directional.prefab'

    local glb = "/pkg/tools.viewer.prefab_viewer/res/root.glb"
    if fs.exists(fs.path(glb)) then
        createPrefab(glb .. "|mesh.prefab")
    end
end

function m:post_init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
end

function m:data_changed()
    for _, filename in eventResetPrefab:unpack() do
        createPrefab(filename)
    end
end
