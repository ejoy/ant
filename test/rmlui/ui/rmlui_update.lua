local thread = require "thread"
local channel = thread.channel_consume "rmlui"

local CMD = {}
local contexts = {}

function CMD.CreateContext(name, w, h)
    rmlui:CreateContext(name, Vector2i.new(w, h))
    contexts[#contexts+1] = name
end

function CMD.LoadDocument(name, path)
    local ctx = rmlui.contexts[name]
    if ctx then
        local doc = ctx:LoadDocument(path)
        if doc then
            doc:Show()
        end
    end
end

function CMD.MouseMove(x, y)
    for _, name in ipairs(contexts) do
        local ctx = rmlui.contexts[name]
        if ctx then
            ctx:ProcessMouseMove(x, y)
        end
    end
end

function CMD.MouseDown(button)
    for _, name in ipairs(contexts) do
        local ctx = rmlui.contexts[name]
        if ctx then
            ctx:ProcessMouseButtonDown(button)
        end
    end
end

function CMD.MouseUp(button)
    for _, name in ipairs(contexts) do
        local ctx = rmlui.contexts[name]
        if ctx then
            ctx:ProcessMouseButtonUp(button)
        end
    end
end

function CMD.Debugger(open)
    if contexts[1] then
        local ctx = rmlui.contexts[contexts[1]]
        if ctx then
            ctx:Debugger(open)
        end
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

return function ()
    while message(channel:pop()) do
    end
    for _, name in ipairs(contexts) do
        local ctx = rmlui.contexts[name]
        if ctx then
            ctx:Update()
            ctx:Render()
        end
    end
end
