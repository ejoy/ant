local ecs = ...
local world = ecs.world

local eff_test_sys = ecs.system "effect_test_system"

function eff_test_sys:init()
    -- world:instance("/pkg/ant.test.features/assets/entities/fullscreen_billboard.prefab", {
    --     root=world:singleton_entity "main_queue".camera_eid})

    -- world:instance("/pkg/ant.test.features/assets/entities/billboard_test.prefab", 
    --     {root=world:singleton_entity "main_queue".camera_eid})

    --world:instance "/pkg/ant.test.features/assets/entities/star.prefab"

    --world:instance "/pkg/ant.test.features/assets/entities/particle_test.prefab"
end