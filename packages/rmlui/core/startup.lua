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
local debuggerInitialized = false

local ServiceWindow = ltask.queryservice "ant.window|window"

rmlui.RmlRegisterEevent(require "core.callback")

local _, last = ltask.now()
local function getDelta()
    local _, now = ltask.now()
    local delta = now - last
    last = now
    return delta * 10
end

local function Render()
    local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
    ltask.call(ServiceBgfxMain, "encoder_init")
    while not quit do
        local delta = getDelta()
        if delta > 0 then
            timer.update(delta)
        end
        rmlui.RenderBegin()
        rmlui.ContextUpdate(context, delta)
        rmlui.RenderFrame()
        task.update()
        ltask.call(ServiceBgfxMain, "encoder_frame")
    end
	ltask.call(ServiceBgfxMain, "encoder_release")
    ltask.wakeup(quit)
end

local function updateContext(c)
    context = c
    event("OnContextChange", context)
end

local S = {}

function S.initialize(t)
    ServiceWorld = t.service_world
    require "font" (t.font_mgr)
    initRender(t)
    local c = rmlui.RmlCreateContext(t.viewrect.w, t.viewrect.h)
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
    ltask.quit()
end

function S.mouse(x, y, type, state)
    if not context then
        return
    end
    --local MOUSE_TYPE_NONE <const> = 0
    --local MOUSE_TYPE_LEFT <const> = 1
    --local MOUSE_TYPE_RIGHT <const> = 2
    --local MOUSE_TYPE_MIDDLE <const> = 3
    local MOUSE_STATE_DOWN <const> = 1
    local MOUSE_STATE_MOVE <const> = 2
    local MOUSE_STATE_UP <const> = 3
    if state == MOUSE_STATE_MOVE then
        rmlui.ContextProcessMouseMove(context, type-1, x, y)
    elseif state == MOUSE_STATE_DOWN then
        rmlui.ContextProcessMouseButtonDown(context, type-1, x, y)
    elseif state == MOUSE_STATE_UP then
        rmlui.ContextProcessMouseButtonUp(context, type-1, x, y)
    end
end

function S.touch(x, y, _, state)
    if not context then
        return
    end
    local TOUCH_STATE_DOWN <const> = 1
    local TOUCH_STATE_MOVE <const> = 2
    local TOUCH_STATE_UP <const> = 3
    if state == TOUCH_STATE_MOVE then
        rmlui.ContextProcessMouseMove(context, 0, x, y)
    elseif state == TOUCH_STATE_DOWN then
        rmlui.ContextProcessMouseButtonDown(context, 0, x, y)
    elseif state == TOUCH_STATE_UP then
        rmlui.ContextProcessMouseButtonUp(context, 0, x, y)
    end
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

function S.update_viewrect(x, y, w, h)
    rmlui.UpdateViewrect(x, y, w, h)
    if context then
        rmlui.ContextUpdateSize(context, w, h)
    end
end

S.open = windowManager.open
S.close = windowManager.close
S.postMessage = windowManager.postMessage
S.preload_dir = filemanager.preload_dir

ltask.send(ServiceWindow, "subscribe", "mouse", "touch")

return S
