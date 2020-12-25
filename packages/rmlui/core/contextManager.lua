local m = {}

local context
local debuggerInitialized = false

function m.initialize(width, height)
    context = rmlui.RmlCreateContext(width, height)
end

function m.destroy()
    rmlui.RmlRemoveContext(context)
end

function m.open(url)
    if context then
        local document = rmlui.ContextLoadDocument(context, url)
        if document then
            rmlui.DocumentShow(document)
            return document
        end
    end
end

function m.close(document)
    rmlui.ContextUnloadDocument(context, document)
end

function m.mouseMove(x, y)
    rmlui.ContextProcessMouseMove(context, x, y)
end

function m.mouseDown(button)
    rmlui.ContextProcessMouseButtonDown(context, button)
end

function m.mouseUp(button)
    rmlui.ContextProcessMouseButtonUp(context, button)
end

function m.debugger(open)
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

function m.update()
    rmlui.RenderBegin()
    rmlui.ContextUpdate(context)
    rmlui.RenderFrame()
end

return m
