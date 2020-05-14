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
    local size = math3d.tovalue(math3d.sub(math3d.index(aabb, 2), math3d.index(aabb, 1)))
    local scale = 1/math.max(table.unpack(size))
    for _, eid in ipairs(entities) do
        local e = world[eid]
        if e.transform then
            e.transform.srt.s = math3d.mul(scale, e.transform.srt.s)
        end
    end
end

function m:init()
    renderpkg.components.create_grid_entity(world, "", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
    world:instance '/pkg/tools.viewer.prefab_viewer/light_directional.prefab'

    local prefab = "/pkg/tools.viewer.prefab_viewer/res/mesh.prefab"
    if fs.exists(fs.path(prefab)) then
        createPrefab(prefab)
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
