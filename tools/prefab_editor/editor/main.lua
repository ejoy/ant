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

function cb.exit()
    for _, w in ipairs(worlds) do
        w.exit()
    end
    event "exit"
end

function cb.mouse_wheel(x, y, delta)
    local mvp = imgui.GetMainViewport()
    x, y = x - mvp.WorkPos[1], y - mvp.WorkPos[2]
    for _, w in ipairs(worlds) do
        w.mouse_wheel(x, y, delta)
    end
end
function cb.mouse(x, y, what, state)
    local mvp = imgui.GetMainViewport()
    x, y = x - mvp.MainPos[1], y - mvp.MainPos[2]
    for _, w in ipairs(worlds) do
        w.mouse(x, y, what, state)
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

return cb
