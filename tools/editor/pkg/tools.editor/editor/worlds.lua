local ecs      = import_package "ant.ecs"

local function create_world(config)
    local world = ecs.new_world (config)
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
    function m.mousewheel(e)
        world:inputmgr_dispatch(e)
    end
    function m.mouse(e)
        world:inputmgr_dispatch(e)
    end
    function m.keyboard(e)
        world:inputmgr_dispatch(e)
    end
    function m.size(e)
        world:inputmgr_dispatch(e)
    end
    function m.set_viewrect(vr)
        world:set_viewrect(vr)
    end
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
