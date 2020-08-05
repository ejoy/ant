local ecs = ...
local world = ecs.world

local sb_test_sys = ecs.system "skybox_test_system"
function sb_test_sys.init()
    world:instance "/pkg/ant.test.features/assets/entities/skybox_test.prefab"
end