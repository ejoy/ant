local ecs = ...
local world = ecs.world

local eff_test_sys = ecs.system "effect_test_system"

function eff_test_sys:init()
    world:instance("/pkg/ant.test.features/assets/entities/billboard.prefab", {
        root=world:singleton_entity "main_queue".camera_eid})
end