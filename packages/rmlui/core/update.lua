local thread = require "thread"
local rmlui = require "rmlui"
local channel = thread.channel_consume "rmlui"

local CMD = {}
local contexts = {}

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

function CMD.Debugger(open)
    --TODO
    --if contexts[1] then
    --    local ctx = rmlui.contexts[contexts[1]]
    --    if ctx then
    --        ctx:Debugger(open)
    --    end
    --end
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

return function ()
    while message(channel:pop()) do
    end
    for _, ctx in ipairs(contexts) do
        rmlui.ContextUpdate(ctx)
        rmlui.ContextRender(ctx)
    end
end
