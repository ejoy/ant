local ecs = ...
local world = ecs.world
local m = ecs.system 'init_system'
local irq = world:interface "ant.render|irenderqueue"
local math3d = require "math3d"
function m:init()
    irq.set_view_clear_color(world:singleton_entity_id "main_queue", 0)

    world:prefab_instance "res/scenes.prefab"
    -- local prefab = world:prefab_instance "res/Fox.glb|mesh.prefab"
    -- -- prefab_event(prefab, event, tag, param)
    -- world:prefab_event(prefab, "autoplay", "fox", "Survey")
    -- local camera_prefab = world:instance "res/camera.prefab"
    local camera_prefab = world:prefab_instance "res/camera.prefab"
    local prefab = world:prefab_instance "res/female.prefab"
    --[[
        autoplay : auto play animation
        play     : play animation
        duration : get current animation duration
        time     : set animtion current time
        set_clips: set animtion clips
        set_position
        set_rotation
        set_scale
        get_position
        get_rotation
        get_scale
    --]]
    local cam_pos = world:prefab_event(camera_prefab, "get_position", "camera")
    local tpos = math3d.totable(cam_pos)
    --world:prefab_event(camera_prefab, "set_position", "camera", {1, 1, 1})
    local tag = "body"
    world:prefab_event(prefab, "autoplay", tag, "walking")
    -- world:prefab_event(prefab, "set_events", tag, "walking", "res/walking.event")
    -- local collider = world:prefab_event(prefab, "get_collider", tag, "walking", 0.3)
    -- world:prefab_event(prefab, "play", tag, "running")
    -- world:prefab_event(prefab, "time", tag, 0.08)
    -- local duration = world:prefab_event(prefab, "duration", tag)
    -- world:prefab_event(prefab, "set_position", tag, {1, 0, 0})
    local female_pos = world:prefab_event(prefab, "get_position", tag)
    -- world:prefab_event(prefab, "set_rotation", tag, {45, 0, 0})
    world:prefab_event(prefab, "set_scale", tag, {0.5, 0.5, 0.5})
    -- test clip and group
    -- world:prefab_event(prefab, "set_clips", tag, "res/test.clip")
    -- world:prefab_event(prefab, "autoplay", tag, "Clip2")
    -- world:prefab_event(prefab, "autoplay", tag, "Clip0")
    -- world:prefab_event(prefab, "autoplay", tag, "Clip1")
    -- world:prefab_event(prefab, "autoplay", tag, "Group0")
end
