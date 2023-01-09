local ecs = ...
local world = ecs.world
local dst = ecs.system "decal_test_system"
function dst:init()
    local p = ecs.create_instance "/pkg/ant.test.features/assets/entities/decal.prefab"

end