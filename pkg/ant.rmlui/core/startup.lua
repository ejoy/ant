local rmlui = require "rmlui"

local timer = require "core.timer"
local task = require "core.task"
local filemanager = require "core.filemanager"
local windowManager = require "core.windowManager"
local contextManager = require "core.contextManager"
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
        contextManager.update(delta)
        task.update()
        audio.frame()
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end

local S = {}

function S.initialize(t)
    bgfx.init()
    audio.init()
    ServiceWorld = t.service_world
    require "font" (t.font_mgr)
    initRender(t)
    ltask.fork(Render)
end

function S.shutdown()
    quit = {}
    ltask.wait(quit)
    rmlui.RmlShutdown()
    bgfx.shutdown()
end

S.open = windowManager.open
S.close = windowManager.close
S.postMessage = windowManager.postMessage
S.add_bundle = filemanager.add_bundle
S.del_bundle = filemanager.del_bundle
S.set_prefix = filemanager.set_prefix
S.mouse = contextManager.process_mouse
S.touch = contextManager.process_touch
S.gesture = contextManager.process_gesture
S.update_context_size = contextManager.set_dimensions

return S
