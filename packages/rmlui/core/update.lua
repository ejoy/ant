local thread = require "thread"
local rmlui = require "rmlui"
local timer = require "core.timer"
local channel = thread.channel_consume "rmlui"

local filemanager = require "core.filemanager"

local CMD = {}
local contexts = {}
local debuggerInitialized = false

function CMD.CreateContext(name, w, h)
    local ctx = rmlui.RmlCreateContext(name, w, h)
    contexts[#contexts+1] = ctx
    contexts[name] = ctx
end

function CMD.LoadDocument(name, path)
    local ctx = contexts[name]
    if ctx then
        local doc = rmlui.ContextLoadDocument(ctx, path)
        if doc then
            rmlui.DocumentShow(doc)
        end
    end
end

function CMD.MouseMove(x, y)
    for _, ctx in ipairs(contexts) do
        rmlui.ContextProcessMouseMove(ctx, x, y)
    end
end

function CMD.MouseDown(button)
    for _, ctx in ipairs(contexts) do
        rmlui.ContextProcessMouseButtonDown(ctx, button)
    end
end

function CMD.MouseUp(button)
    for _, ctx in ipairs(contexts) do
        rmlui.ContextProcessMouseButtonUp(ctx, button)
    end
end

function CMD.AddResourceDir(dir)
    filemanager.add(dir)
end

function CMD.Debugger(open)
    local ctx = contexts[1]
    if ctx then
        if not debuggerInitialized then
            rmlui.DebuggerInitialise(ctx)
            debuggerInitialized = true
        else
            rmlui.DebuggerSetContext(ctx)
        end
        rmlui.DebuggerSetVisible(open)
    end
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
    rmlui.RenderBegin()
    for _, ctx in ipairs(contexts) do
        rmlui.ContextUpdate(ctx)
        rmlui.ContextRender(ctx)
    end
    rmlui.RenderFrame()
end
