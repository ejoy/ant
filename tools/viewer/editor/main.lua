local editor        = import_package "ant.imguibase".editor
local imgui         = require "imgui.ant"
local task          = require "task"
local event         = require "event"
local worlds        = require "worlds"
local cb = {}

function cb.init()
    require "prefab_viewer"
    event "init"
end

function cb.update(delta)
    for _, w in ipairs(worlds) do
        w.update()
    end
    task.update(delta)
    event "update"
    imgui.windows.SetNextWindowPos(0, 0)
    event "prefab_viewer"
    imgui.windows.SetNextWindowPos(768, 0)
    imgui.windows.SetNextWindowSize(1024-768, 768)
    event "prefab_editor"
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
function cb.dropfiles(filelst)
    event("dropfiles", filelst)
end
editor.start(1024, 768, cb)
