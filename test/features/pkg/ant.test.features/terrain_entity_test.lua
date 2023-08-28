local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d = require "math3d"

local tet_sys = ecs.system "terrain_entity_test_system"

local grid_w<const>, grid_h<const> = 8, 8
local entity_size_in_grid<const> = 2
local group_size_in_entity<const> = 2

local base_group_id<const> = 10

local w_in_entity, h_in_entity = grid_w // entity_size_in_grid, grid_h // entity_size_in_grid
local num_groups<const> = (w_in_entity // group_size_in_entity) * (h_in_entity // group_size_in_entity)
local prefabfile = "/pkg/ant.test.features/assert/entities/ground_01.prefab"

local function group_id(iw, ih)
    local gx, gy = iw // group_size_in_entity, ih // group_size_in_entity

    local localgid = (gy-1) * group_size_in_entity + gx
    assert(localgid <= num_groups+base_group_id)
    return localgid + base_group_id
end

local function tag_name(gid)
    return "terrain_group_" .. gid
end

function tet_sys:init()
    for ih=1, h_in_entity do
        for iw=1, w_in_entity do
            local gid = group_id(iw, ih)
            local tagname = tag_name(gid)
            w:register{name=tagname}
            local p = world:create_instance(prefabfile, nil, gid)
            p.on_ready = function (e)
                for _, eid in ipairs(e.tag["*"]) do
                    world[eid][tagname] = true
                end
            end
            world:create_object(p)
        end
    end
end

local camera_changed_mb

function tet_sys:init_world()
    
end

local mq_cc_mb = world:sub{"main_queue", "camera_changed"}

local group_aabbs = {dirty=true}
local function update_group(ce)
    local frustum_planes = math3d.frustum_planes(ce.camera.viewprojmat)
    for gid, aabb in pairs(group_aabbs) do
        local culled = math3d.frustum_intersect_aabb(frustum_planes, aabb) < 0
        if culled then
            world:group_disable_tag("view_visible", gid)
        else
            world:group_enable_tag("view_visible", gid)
        end
    end
    world:group_flush "view_visible"
end

function tet_sys:data_changed()
end

function tet_sys:camera_usage()
    if group_aabbs.dirty then
        group_aabbs.dirty = nil

        for ih=1, h_in_entity do
            for iw=1, w_in_entity do
                local gid = group_id(iw, ih)
                local tagname = tag_name(gid)
                local gaabb = group_aabbs[gid]
                if gaabb == nil then
                    gaabb = math3d.ref(math3d.aabb())
                    group_aabbs[gid] = gaabb
                end
                for e in w:select(("%s scene:in"):format(tagname)) do
                    math3d.aabb_merge(gaabb, e.scene.scene_aabb)
                end
            end
        end
    end
    if w:check "scene_changed" then
        local mq = w:first("main_queue camera_ref:in")
        local mc<close> = world:entity(mq.camera_ref)
        if mc.scene_changed then
            update_group(mc)
        end
    end
end