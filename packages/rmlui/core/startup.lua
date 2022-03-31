local rmlui = require "rmlui"

local timer = require "core.timer"
local task = require "core.task"
local filemanager = require "core.filemanager"
local windowManager = require "core.windowManager"
local contextManager = require "core.contextManager"
local initRender = require "core.initRender"
local ltask = require "ltask"

require "core.DOM.constructor":init()

local quit

local ServiceWindow = ltask.queryservice "ant.window|window"

local bgfx = require "bgfx"
local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
for _, name in ipairs(ltask.call(ServiceBgfxMain, "APIS")) do
	bgfx[name] = function (...)
		return ltask.call(ServiceBgfxMain, name, ...)
	end
end

local _, last = ltask.now()
local function getDelta()
    local _, now = ltask.now()
    local delta = now - last
    last = now
    return delta * 10
end

local function Render()
    bgfx.encoder_create()
    while not quit do
        local delta = getDelta()
        if delta > 0 then
            timer.update(delta)
        end
        rmlui.RenderBegin()
        contextManager.update(delta)
        rmlui.RenderFrame()
        task.update()
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end

local S = {}

function S.initialize(t)
    bgfx.init()
    ServiceWorld = t.service_world
    require "font" (t.font_mgr)
    initRender(t)
    rmlui.RmlRegisterEevent(require "core.callback")
    ltask.fork(Render)
end

function S.shutdown()
    quit = {}
    ltask.wait(quit)
	ltask.send(ServiceWindow, "unsubscribe_all")
    rmlui.RmlShutdown()
    bgfx.shutdown()
    ltask.quit()
end

S.open = windowManager.open
S.close = windowManager.close
S.postMessage = windowManager.postMessage
S.font_dir = filemanager.font_dir
S.preload_dir = filemanager.preload_dir
S.mouse = contextManager.process_mouse
S.touch = contextManager.process_touch
S.gesture = contextManager.process_gesture
S.update_context_size = contextManager.set_dimensions

ltask.send(ServiceWindow, "subscribe", "priority=1", "mouse", "touch", "gesture")

return S
