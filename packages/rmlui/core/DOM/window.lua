local event = require "core.event"
local timer = require "core.timer"
local contextManager = require "core.contextManager"
local createEvent = require "core.DOM.event"
local createExternWindow = require "core.externWindow"

local datamodels = {}
local datamodel_mt = {
    __index = rmlui.DataModelGet,
    __call  = rmlui.DataModelDirty,
    __gc    = rmlui.DataModelDelete,
}
function datamodel_mt:__newindex(k, v)
    if type(v) == "function" then
        local ov = v
        v = function(e,...)
            ov(createEvent(e), ...)
        end
    end
    rmlui.DataModelSet(self,k,v)
end

function event.OnContextCreate(context)
    datamodels[context] = {}
end

function event.OnContextDestroy(context)
    for _, model in pairs(datamodels[context]) do
        rmlui.DataModelRelease(model)
    end
    datamodels[context] = nil
end

local function createWindow(document, source)
    --TODO: pool
    local window = {}
    function window.createModel(name)
        return function (init)
            local context = rmlui.DocumentGetContext(document)
            local model = rmlui.DataModelCreate(context, name, init)
            datamodels[context][name] = model
            debug.setmetatable(model, datamodel_mt)
            return model
        end
    end
    function window.open(url)
        local newdoc = contextManager.open(url)
        if not newdoc then
            return
        end
        event("OnDocumentExternName", newdoc, document)
        return createWindow(newdoc, document)
    end
    function window.close()
        contextManager.close(rmlui.DocumentGetContext(document))
    end
    function window.setTimeout(f, delay)
        return timer.wait(delay, f)
    end
    function window.setInterval(f, delay)
        return timer.loop(delay, f)
    end
    function window.clearTimeout(t)
        t:remove()
    end
    function window.clearInterval(t)
        t:remove()
    end
    function window.addEventListener(type, listener, useCapture)
        rmlui.ElementAddEventListener(document, type, function(e) listener(createEvent(e)) end, useCapture)
    end
    function window.postMessage(data)
        rmlui.ElementDispatchEvent(document, "message", {
            source = source,
            data = data,
        })
    end
    return window
end

function event.OnNewDocument(document, globals)
    globals.window = createWindow(document)
    globals.window.extern = createExternWindow(document)
end

return createWindow
