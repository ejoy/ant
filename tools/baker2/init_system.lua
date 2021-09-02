local ecs = ...
local world = ecs.world
local ientity = world:interface "ant.render|entity"
local is = ecs.system "init_system"

function is:init()
    ientity.create_grid_entity("polyline_grid", 64, 64, 1, 5)
    world:instance "/pkg/ant.tool.baker/assets/scene/scene.prefab"
end

function is:data_changed()
    
end