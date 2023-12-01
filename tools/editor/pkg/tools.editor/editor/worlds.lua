local ecs      = import_package "ant.ecs"
local inputmgr = import_package "ant.inputmgr"

local function create_world(config)
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
    m.mousewheel   = ev.mousewheel
    m.mouse        = ev.mouse
    m.keyboard     = ev.keyboard
    m.size         = ev.size
    m.set_viewport = ev.set_viewport
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
