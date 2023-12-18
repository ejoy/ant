local ecs   = ...
local world = ecs.world
local w     = world.w
local queuemgr	= ecs.require "ant.render|queue_mgr"
local sbp_sys = ecs.system "scene_bounding_pack_system"
local math3d    = require "math3d"
local mc = import_package "ant.math".constant

local Q         = world:clibs "render.queue"

local dirty

function sbp_sys:entity_remove()
    if not dirty then
        dirty = w:first "REMOVED scene bounding" 
    end
end

local function merge_aabb(queue_index, visble_idx, cull_idx, entity_scene_aabb, whole_scene_aabb)
    if Q.check(visble_idx, queue_index) and not Q.check(cull_idx, queue_index) then
        if entity_scene_aabb and entity_scene_aabb ~= mc.NULL then
            whole_scene_aabb = math3d.aabb_merge(whole_scene_aabb, entity_scene_aabb) 
        end
    end
    return whole_scene_aabb
end

function sbp_sys:finish_scene_update()
    if not dirty then
        dirty = w:first "scene_changed scene bounding" 
    end
    local sbe = w:first "shadow_bounding:update"
    if sbe then
        local scene_aabb = math3d.aabb()
        local qidx = assert(queuemgr.queue_index "main_queue")
        for e in w:select "render_object_visible bounding:in render_object:in" do
            scene_aabb = merge_aabb(qidx, e.render_object.visible_idx, e.render_object.cull_idx, e.bounding.scene_aabb, scene_aabb)
        end
        for e in w:select "hitch_visible bounding:in hitch:in" do
            scene_aabb = merge_aabb(qidx, e.hitch.visible_idx, e.hitch.cull_idx, e.bounding.scene_aabb, scene_aabb)
        end
        
        if math3d.aabb_isvalid(scene_aabb) then
            math3d.unmark(sbe.shadow_bounding.scene_aabb)
            sbe.shadow_bounding.scene_aabb = math3d.marked_aabb(math3d.array_index(scene_aabb, 1), math3d.array_index(scene_aabb, 2))
        end

        w:submit(sbe) 
    end
    dirty = false
end