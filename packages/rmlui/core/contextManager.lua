local m = {}

local contexts = {}
local debuggerInitialized = false
local width, height
local find = {}
local maxId = 0

function m.initialize(w, h)
    width, height = w, h
end

function m.open(url)
    maxId = maxId+1
    local name = ''..maxId
    local ctx = rmlui.RmlCreateContext(name, width, height)
    if ctx then
        local doc = rmlui.ContextLoadDocument(ctx, url)
        if doc then
            rmlui.DocumentShow(doc)
            contexts[#contexts+1] = ctx
            find[ctx] = name
            return doc
        else
            rmlui.RmlRemoveContext(name)
        end
    end
end

function m.close(ctx)
    local name = find[ctx]
    find[ctx] = nil
    rmlui.RmlRemoveContext(name)
    for i, c in ipairs(contexts) do
        if c == ctx then
            table.remove(contexts, i)
        end
    end
end

function m.mouseMove(x, y)
    for _, ctx in ipairs(contexts) do
        rmlui.ContextProcessMouseMove(ctx, x, y)
    end
end

function m.mouseDown(button)
    for _, ctx in ipairs(contexts) do
        rmlui.ContextProcessMouseButtonDown(ctx, button)
    end
end

function m.mouseUp(button)
    for _, ctx in ipairs(contexts) do
        rmlui.ContextProcessMouseButtonUp(ctx, button)
    end
end

function m.debugger(open)
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

function m.update()
    rmlui.RenderBegin()
    for _, ctx in ipairs(contexts) do
        rmlui.ContextUpdate(ctx)
        rmlui.ContextRender(ctx)
    end
    rmlui.RenderFrame()
end

return m
