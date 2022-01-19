local ecs      = import_package "ant.ecs"
local inputmgr = import_package "ant.inputmgr"
local wu       = require "widget.utils"
local imgui    = require "imgui"

local function create_world(config)
    local fbw, fbh = config.fbw, config.fbh
    config.viewport = {x=0, y=0, w=1, h=1}
    local world = ecs.new_world (config)
    local ev = inputmgr.create(world, "imgui")
    local m = {}
    function m.init()
        world:pub {"resize", fbw, fbh}
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
        config.name = name
        local w, world = create_world(config)
        worlds[#worlds+1] = w
        w.init()
        return w, world
    end
end

return worlds
