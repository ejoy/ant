local editor        = import_package "ant.imgui"
local imgui         = require "imgui"
local task          = require "task"
local event         = require "event"
local worlds        = require "worlds"
local cb = {}

function cb.init(width, height)
    require "editor_impl"
    event("init", width, height)
end

function cb.update(delta)
    for _, w in ipairs(worlds) do
        w.update()
    end
    task.update(delta)
    event "update"
end
function cb.mouse_wheel(x, y, delta)
    for _, w in ipairs(worlds) do
        w.mouse_wheel(x, y, delta)
    end
end
function cb.mouse(x, y, what, state)
    for _, w in ipairs(worlds) do
        w.mouse(x, y, what, state)
    end
end
function cb.keyboard(key, press, state)
    for _, w in ipairs(worlds) do
        w.keyboard(key, press, state)
    end
end
function cb.size(width, height)
    for _, w in ipairs(worlds) do
        w.size(width, height)
    end
end
function cb.dropfiles(filelst)
    event("dropfiles", filelst)
end

editor.start(1280, 720, cb)
