local rmlui = require "rmlui"
local timer = require "core.timer"
local task = require "core.task"
local extern_windows = require "core.extern_windows"
local document_manager = require "core.document_manager"
local initRender = require "core.initRender"
local audio = import_package "ant.audio"
local ltask = require "ltask"
local bgfx = require "bgfx"

require "core.DOM.constructor":init()

local quit

local _, last = ltask.now()
local function getDelta()
    local _, now = ltask.now()
    local delta = now - last
    last = now
    return delta * 10
end

local function Render()
    bgfx.encoder_create "rmlui"
    while not quit do
        local delta = getDelta()
        if delta > 0 then
            timer.update(delta)
        end
        document_manager.update(delta)
        task.update()
        audio.frame()
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end

local S = {}

function S.shutdown()
    quit = {}
    ltask.wait(quit)
    rmlui.RmlShutdown()
    bgfx.shutdown()
end

function S.open(...)
    extern_windows.push("open", ...)
end

function S.close(...)
    extern_windows.push("close", ...)
end

function S.postMessage(...)
    extern_windows.push("postMessage", ...)
end

S.gesture = document_manager.process_gesture
S.touch = document_manager.process_touch
S.update_context_size = document_manager.set_dimensions

bgfx.init()
audio.init()
initRender()
ltask.fork(Render)

return S
