local rmlui = require "rmlui"
local event = require "core.event"
local data_event = require "core.datamodel.event"

local datamodels = {}

local m = {}

function m.create(document, view)
    local model = rmlui.DataModelCreate(document, view)
    datamodels[document] = {
        model = model,
        view = view,
        variables = {},
        events = {},
    }
    local mt = {
        __index = rmlui.DataModelGet,
        __call  = rmlui.DataModelDirty,
    }
    function mt:__newindex(k, v)
        view[k] = v
        if type(v) == "function" then
            return
        end
        rmlui.DataModelSet(self,k,v)
    end
    debug.setmetatable(model, mt)
    return model
end

function m.load(document, element, name, value)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    local type, modifier = name:match "data%-(%a+)%-(%a+)"
    if type == "event" then
        data_event.load(datamodel, element, modifier, value)
    end
end

function m.setVariable(document, element, name, value)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    local vars = datamodel.variables[element]
    if not vars then
        vars = {}
        datamodel.variables[element] = vars
    end
    vars[name] = value
    data_event.setVariable(datamodel, element)
end

function m.refresh(document)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    data_event.refresh(datamodel)
end

function event.OnDestroyNode(document, node)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    datamodel.variables[node] = nil
    data_event.destroyNode(datamodel, node)
end

function event.OnDocumentCreate(document)
    datamodels[document] = nil
end

function event.OnDocumentDestroy(document)
    local md = datamodels[document]
    if md then
        rmlui.DataModelRelease(md.model)
        datamodels[document] = nil
    end
end

return m
