local ecs = ...
local world = ecs.world
local dst = ecs.system "decal_test_system"
function dst:init()
    local p = world:instance "/pkg/ant.test.features/assets/entities/decal.prefab"

end