local ecs      = import_package "ant.ecs"
local inputmgr = import_package "ant.inputmgr"

local function create_world(config)
    config.viewport = {x=0, y=0, w=1, h=1}
    local world = ecs.new_world (config)
    local ev = inputmgr.create(world, "imgui")
    local m = {}
    function m.init()
        world:pipeline_init()
    end
    function m.update()
        world:pipeline_update()
    end
    function m.exit()
        world:pipeline_exit()
    end
    m.mouse_wheel   = ev.mouse_wheel
    m.mouse         = ev.mouse
    m.keyboard      = ev.keyboard
    m.size          = ev.size
    return m, world
end

local worlds = {}

function worlds.create(name)
    return function (config)
        config.name = name
        local w, world = create_world(config)
        worlds[#worlds+1] = w
        w.init()
        return w, world
    end
end

return worlds
