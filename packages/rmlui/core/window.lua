local event = require "core.event"

local datamodels = {}

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
            return model
        end
    end
    globals.window = m
end

