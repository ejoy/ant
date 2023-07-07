local rmlui = require "rmlui"
local event = require "core.event"
local data_event = require "core.datamodel.event"
local data_modifier = require "core.datamodel.modifier"
local data_text = require "core.datamodel.text"

local datamodels = {}

local m = {}

function m.create(document, data_table)
    local model = rmlui.DataModelCreate(document, data_table)
    datamodels[document] = {
        model = model,
        data_table = data_table,
        variables = {},
        views = {},
        texts = {},
    }
    local mt = {
        __index = rmlui.DataModelGet,
        __call  = rmlui.DataModelDirty,
    }
    function mt:__newindex(k, v)
        data_table[k] = v
        if type(v) == "function" then
            return
        end
        rmlui.DataModelSet(self,k,v)
    end
    debug.setmetatable(model, mt)
    return model
end

local function collectVariables(datamodel, element, t)
    local vars = datamodel.variables[element]
    if vars then
        for name, value in pairs(vars) do
            if not t[name] then
                t[name] = value
            end
        end
    end
    local parent = rmlui.NodeGetParent(element)
    if parent then
        return collectVariables(datamodel, parent, t)
    end
    return t
end

local function compileVariables(datamodel, element)
    local variables = collectVariables(datamodel, element, {})
    local s = {}
    for name, value in pairs(variables) do
        s[#s+1] = ("local %s = %s"):format(name, value)
    end
    return table.concat(s, "\n")
end

function m.load(document, element, name, value)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    if name == "data-text" then
        local view = datamodel.texts[element]
        if not view then
            view = {
                variables = compileVariables(datamodel, element)
            }
            datamodel.texts[element] = view
        end
        data_text.load(datamodel, view, element, value)
        return
    end
    local view = datamodel.views[element]
    if not view then
        view = {
            events = {},
            modifiers = {
                style = {},
                attr = {},
                ["if"] = {},
            },
            variables = compileVariables(datamodel, element)
        }
        datamodel.views[element] = view
    end
    if name == "data-if" then
        data_modifier.load(datamodel, view, element, "if", "", value)
    else
        local type, modifier = name:match "^data%-(%a+)%-(.+)$"
        if type == "event" then
            data_event.load(datamodel, view, element, modifier, value)
        elseif type == "style" or type == "attr" then
            data_modifier.load(datamodel, view, element, type, modifier, value)
        else
            error("unknown data-model attribute:"..name)
        end
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
end

function m.refresh(document)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    for element, view in pairs(datamodel.views) do
        data_event.refresh(datamodel, view)
        data_modifier.refresh(datamodel, element, view)
    end
    data_text.refresh(datamodel)
end

function event.OnDestroyNode(document, node)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    datamodel.variables[node] = nil
    local view = datamodel.views[node]
    if view then
        data_event.destroyNode(view, node)
    end
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
