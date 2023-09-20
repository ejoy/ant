local ecs   = ...
local world = ecs.world
local w     = world.w
local queuemgr	= ecs.require "ant.render|queue_mgr"
local sbp_sys = ecs.system "scene_bounding_pack_system"
local math3d    = require "math3d"
local mc = import_package "ant.math".constant

local dirty

function sbp_sys:entity_remove()
    if not dirty then
        dirty = w:first "REMOVED scene bounding" 
    end
end

local function merge_aabb(mask, visible_masks, cull_masks, entity_scene_aabb, whole_scene_aabb)
    if (mask & visible_masks) and (mask & cull_masks) then
        if entity_scene_aabb and entity_scene_aabb ~= mc.NULL then
            whole_scene_aabb = math3d.aabb_merge(whole_scene_aabb, entity_scene_aabb) 
        end
    end
    return whole_scene_aabb
end

function sbp_sys:after_scene_update()
    if not dirty then
        dirty = w:first "scene_changed scene bounding" 
    end
    local sbe = w:first "shadow_bounding:update"
    if sbe then
        local scene_aabb = math3d.aabb()
        local mask = assert(queuemgr.queue_mask("main_queue"))
        for e in w:select "render_object_visible bounding:in render_object:in" do
            scene_aabb = merge_aabb(mask, e.render_object.visible_masks, e.render_object.cull_masks, e.bounding.scene_aabb, scene_aabb)
        end
        for e in w:select "hitch_visible bounding:in hitch:in" do
            scene_aabb = merge_aabb(mask, e.hitch.visible_masks, e.hitch.cull_masks, e.bounding.scene_aabb, scene_aabb)
        end
        
        math3d.unmark(sbe.shadow_bounding.scene_aabb)
        sbe.shadow_bounding.scene_aabb = math3d.marked_aabb(math3d.array_index(scene_aabb, 1), math3d.array_index(scene_aabb, 2))
        w:submit(sbe) 
    end
    dirty = false
end