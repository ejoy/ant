local imgui = require "imgui"
local ecs = import_package "ant.ecs"
local cb = {}

local world

function cb.init(width, height, cfg)
    world = ecs.new_world {
        name = "editor",
        scene = {
            viewrect = {x = 0, y = 0, w = width, h = height},
            resolution = {w = width, h = height},
            ratio = 1,
            scene_ratio = 1,
        },
        backbuffer_viewport = {x=0, y=0, w=1920, h=1080},
        ecs = cfg.ecs,
    }
    world:pipeline_init()
end

function cb.update(delta)
    if world then
        world:pipeline_update()
    end
end

function cb.exit()
    if world then
        world:pipeline_exit()
    end
end

function cb.mousewheel(x, y, delta)
    if not world then
        return
    end
    local mvp = imgui.GetMainViewport()
    x, y = x - mvp.WorkPos[1], y - mvp.WorkPos[2]
    world:dispatch_message {
        type = "mousewheel",
        x = x,
        y = y,
        delta = delta,
    }
end
function cb.mouse(x, y, what, state)
    if not world then
        return
    end
    local mvp = imgui.GetMainViewport()
    x, y = x - mvp.MainPos[1], y - mvp.MainPos[2]
    world:dispatch_message {
        type = "mouse",
        x = x,
        y = y,
        what = what,
        state = state,
        timestamp = 0,
    }
end
function cb.keyboard(key, press, state)
    if not world then
        return
    end
    world:dispatch_message {
        type = "keyboard",
        key = key,
        press = press,
        state = state,
    }
end
function cb.size(width, height)
    if not world then
        return
    end
    world:dispatch_message {
        type = "size",
        w = width,
        h = height,
    }
end
function cb.dispatch_message(e)
    if not world then
        return
    end
    world:dispatch_message(e)
end
function cb.dropfiles(filelst)
end

return cb
