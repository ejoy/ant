local thread = require "thread"
local timer = require "core.timer"
local task = require "core.task"
local contextManager = require "core.contextManager"
local fileManager = require "core.fileManager"
local windowManager = require "core.windowManager"
local channel = thread.channel_consume "rmlui_req"

local CMD = {}

CMD.initialize = contextManager.initialize
CMD.mouseMove = contextManager.mouseMove
CMD.mouseDown = contextManager.mouseDown
CMD.mouseUp = contextManager.mouseUp
CMD.debugger = contextManager.debugger
CMD.update_viewrect = contextManager.update_viewrect

CMD.open = windowManager.open
CMD.close = windowManager.close
CMD.postMessage = windowManager.postMessage

function CMD.add_resource_dir(dir)
    fileManager.add(dir)
end

local function message(ok, what, ...)
    if not ok then
        return false
    end
    if CMD[what] then
        CMD[what](...)
    end
    return true
end

return function (delta)
    while message(channel:pop()) do
    end
    timer.update(delta)
    contextManager.update()
    task.update()
end
