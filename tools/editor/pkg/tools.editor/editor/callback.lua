local ImGui         = import_package "ant.imgui"
local task          = require "editor.task"
local event         = require "editor.event"
local worlds        = require "editor.worlds"
local cb = {}

function cb.init(width, height, cfg)
    local ecs = cfg.ecs
    local m, world = worlds.create "editor" {
        scene = {
			viewrect = {x = 0, y = 0, w = width, h = height},
			resolution = {w = width, h = height},
            ratio = 1,
            scene_ratio = 1,
        },
        device_size = {x=0, y=0, w=1920, h=1080},
        ecs = ecs,
    }
    local oldmouse = m.mouse
    m.mouse = function (x, y, ...)
        -- local q = world.w:first("tonemapping_queue render_target:in")
        -- local rt = q.render_target.view_rect
        -- oldmouse(x-rt.x, y-rt.y, ...)
        oldmouse(x, y, ...)
    end
    m.size = function ()
        -- no need to push resize
        -- we check editor scene's view size in gui_system.lua:end_frame function
    end
    event("init", width, height)
end

function cb.update(viewid, delta)
    for _, w in ipairs(worlds) do
        w.update()
    end
    task.update(delta)
    event "update"
end

function cb.exit()
    for _, w in ipairs(worlds) do
        w.exit()
    end
    event "exit"
end

function cb.mousewheel(x, y, delta)
    local mvp = ImGui.GetMainViewport()
    x, y = x - mvp.WorkPos[1], y - mvp.WorkPos[2]
    for _, w in ipairs(worlds) do
        w.mousewheel {
            type = "mousewheel",
            x = x,
            y = y,
            delta = delta,
        }
    end
end
function cb.mouse(x, y, what, state)
    local mvp = ImGui.GetMainViewport()
    x, y = x - mvp.MainPos[1], y - mvp.MainPos[2]
    for _, w in ipairs(worlds) do
        w.mouse {
            type = "mouse",
            x = x,
            y = y,
            what = what,
            state = state,
            timestamp = 0,
        }
    end
end
function cb.keyboard(key, press, state)
    for _, w in ipairs(worlds) do
        w.keyboard {
            type = "keyboard",
            key = key,
            press = press,
            state = state,
        }
    end
end
function cb.size(width, height)
    for _, w in ipairs(worlds) do
        w.size {
            type = "size",
            w = width,
            h = height,
        }
    end
end
function cb.dispatch_message(e)
    for _, w in ipairs(worlds) do
        w.dispatch_message(e)
    end
end
function cb.dropfiles(filelst)
    event("dropfiles", filelst)
end

return cb
