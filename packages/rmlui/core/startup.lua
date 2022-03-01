local rmlui = require "rmlui"

local timer = require "core.timer"
local task = require "core.task"
local event = require "core.event"
local filemanager = require "core.filemanager"
local windowManager = require "core.windowManager"
local initRender = require "core.initRender"
local ltask = require "ltask"

local quit
local context
local screen_ratio = 1.0
local debuggerInitialized = false

local ServiceWindow = ltask.queryservice "ant.window|window"

local bgfx = require "bgfx"
local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
for _, name in ipairs(ltask.call(ServiceBgfxMain, "APIS")) do
	bgfx[name] = function (...)
		return ltask.call(ServiceBgfxMain, name, ...)
	end
end

rmlui.RmlRegisterEevent(require "core.callback")

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
        rmlui.ContextUpdate(context, delta)
        rmlui.RenderFrame()
        task.update()
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end

local function updateContext(c)
    context = c
    event("OnContextChange", context)
end

local S = {}

function S.initialize(t)
    bgfx.init()
    ServiceWorld = t.service_world
    require "font" (t.font_mgr)
    initRender(t)
    local c = rmlui.RmlCreateContext(1, 1)
    updateContext(c)
    ltask.fork(Render)
end

function S.shutdown()
    quit = {}
    ltask.wait(quit)
	ltask.send(ServiceWindow, "unsubscribe_all")
    rmlui.RmlRemoveContext(context)
    updateContext(nil)
    rmlui.RmlShutdown()
    bgfx.shutdown()
    ltask.quit()
end

local function round(x)
    return math.floor(x*screen_ratio+0.5)
end

function S.mouse(x, y, type, state)
    if not context then
        return
    end
    x, y = round(x), round(y)
    return rmlui.ContextProcessMouse(context, type-1, state-1, x, y)
end

function S.touch(state, data)
    if not context then
        return
    end
    return rmlui.ContextProcessTouch(context, state-1, data)
end

function S.gesture_tap(x, y)
    if not context then
        return
    end
    x, y = round(x), round(y)
    local DOWN <const> = 0
    local MOVE <const> = 1
    local UP   <const> = 2
    rmlui.ContextProcessMouse(context, 0, MOVE, x, y)
    rmlui.ContextProcessMouse(context, 0, DOWN, x, y)
    return rmlui.ContextProcessMouse(context, 0, UP, x, y)
end

function S.keyboard(key, press, state)
    if not context then
        return
    end
    rmlui.ContextProcessKey(context, key, press)
    -- stop handle
    return false
end

function S.char(char)
    if not context then
        return
    end
    rmlui.ContextProcessChar(context, char)
    -- stop handle
    return true
end

function S.debugger(open)
    if context then
        if not debuggerInitialized then
            rmlui.DebuggerInitialise(context)
            debuggerInitialized = true
        else
            rmlui.DebuggerSetContext(context)
        end
        rmlui.DebuggerSetVisible(open)
    end
end

function S.update_context_size(w, h, ratio)
    screen_ratio = ratio
    if context then
        rmlui.ContextUpdateSize(context, w, h)
    end
end

S.open = windowManager.open
S.close = windowManager.close
S.postMessage = windowManager.postMessage
S.font_dir = filemanager.font_dir
S.preload_dir = filemanager.preload_dir

ltask.send(ServiceWindow, "subscribe", "priority=1", "mouse", "keyboard", "char", "touch", "gesture_tap")

return S
