local ecs = ...
local world = ecs.world
local w = world.w

local math3d    = require "math3d"

local ientity   = world:interface "ant.render|entity"
local iom       = world:interface "ant.objcontroller|obj_motion"
local is = ecs.system "init_system"

function is:init()
    ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)
    --world:instance "/pkg/ant.test.bake_scene/assets/scene/1.glb|mesh.prefab"
    -- world:instance "/pkg/ant.test.bake_scene/assets/scene/box.prefab"
    world:instance "/pkg/ant.test.bake_scene/assets/scene/light.prefab"
    world:instance "/pkg/ant.test.bake_scene/assets/scene/box.glb|mesh.prefab"
    --world:instance "/pkg/ant.test.bake_scene/assets/scene/box.prefab"
    --world:instance "/pkg/ant.test.bake_scene/assets/scene/scene.prefab"
end

function is:init_world()
    local mq = w:singleton("main_queue", "camera_ref:in")
    local eyepos<const> = math3d.vector(0.0, 2.5, -15.0)
    local dir<const> = math3d.sub(math3d.vector(0.0, 0.0, 0.0), eyepos)
    iom.set_position(mq.camera_ref, eyepos)
    iom.set_direction(mq.camera_ref, dir)
end

function is:data_changed()
    
end