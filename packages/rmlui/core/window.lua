local event = require "core.event"
local createEvent = require "core.DOM.event"

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
    globals.window = m
end

