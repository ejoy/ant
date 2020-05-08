local ecs = ...
local world = ecs.world

local renderpkg  = import_package 'ant.render'

local m = ecs.system 'init_system'

function m:init()
    renderpkg.components.create_grid_entity(world, "", nil, nil, nil, {srt={r = {0,0.92388,0,0.382683},}})
    world:create_entity '/pkg/ant.tools.viewer/light_directional.txt'
end

function m:post_init()
    local e = world:singleton_entity "main_queue"
    e.render_target.viewport.clear_state.color = 0xa0a0a0ff
end
