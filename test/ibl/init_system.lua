local ecs = ...
local world = ecs.world

local is = ecs.system "init_system"
function is:init()
    world:instance "/pkg/ant.test.ibl/assets/skybox.prefab"
    world:instance "/pkg/ant.resources.binary/meshes/DamagedHelmet.glb|mesh.prefab"
end