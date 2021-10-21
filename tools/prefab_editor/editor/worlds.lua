local ecs      = import_package "ant.luaecs"
local inputmgr = import_package "ant.inputmgr"

local function create_world(config)
    local rect_w, rect_h = config.width, config.height
    local world = ecs.new_world (config)
    local ev = inputmgr.create(world, "sdl")
    local m = {}
    function m.init()
        world:pub {"resize", rect_w, rect_h}
        world:pipeline_init()
    end
    function m.update()
        world:pipeline_update()
    end
    function m.exit()
        world:pipeline_exit()
    end
    m.mouse_wheel = ev.mouse_wheel
    m.mouse = ev.mouse
    m.keyboard = ev.keyboard
    function m.size(width, height)
        world:pub {"resize", width, height}
    end
    return m, world
end

local worlds = {}

function worlds.create(name)
    return function (config)
        local w, world = create_world(config)
        worlds[#worlds+1] = w
        return w, world
    end
end

return worlds
