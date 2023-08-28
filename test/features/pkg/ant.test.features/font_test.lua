local ecs = ...
local fonttest_sys = ecs.system "font_test_system"
function fonttest_sys.init()
    world:create_instance "/pkg/ant.test.features/assets/entities/fonttest.prefab"
end