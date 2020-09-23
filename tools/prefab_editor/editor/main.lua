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
function cb.mouse_wheel(...)
    for _, w in ipairs(worlds) do
        w.mouse_wheel(...)
    end
end
function cb.mouse(...)
    for _, w in ipairs(worlds) do
        w.mouse(...)
    end
end
function cb.keyboard(...)
    for _, w in ipairs(worlds) do
        w.keyboard(...)
    end
end
function cb.size(...)
    for _, w in ipairs(worlds) do
        w.size(...)
    end
end
function cb.dropfiles(filelst)
    event("dropfiles", filelst)
end

editor.start(1280, 720, cb)
