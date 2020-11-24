local event = require "core.event"
local timer = require "core.timer"
local createEvent = require "core.DOM.event"
local environment = require "core.environment"

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

function event.OnNewDocument(document, globals)
    local m = {}
    function m.createModel(name)
        return function (init)
            local context = rmlui.DocumentGetContext(document)
            local model = rmlui.DataModelCreate(context, name, init)
            datamodels[context][name] = model
            debug.setmetatable(model, datamodel_mt)
            return model
        end
    end
    function m.open(url)
        local context = rmlui.DocumentGetContext(document)
        local newdoc = rmlui.ContextLoadDocument(context, url)
        if not newdoc then
            return
        end
        rmlui.DocumentShow(newdoc)
        return environment[newdoc]
    end
    function m.close()
        rmlui.DocumentClose(document)
    end
    function m.setTimeout(f, delay)
        return timer.wait(delay, f)
    end
    function m.setInterval(f, delay)
        return timer.loop(delay, f)
    end
    function m.clearTimeout(t)
        t:remove()
    end
    function m.clearInterval(t)
        t:remove()
    end
    globals.window = m
end

