local rmlui = require "rmlui"
local event = require "core.event"
local data_for = require "core.datamodel.for"
local data_event = require "core.datamodel.event"
local data_text = require "core.datamodel.text"
local data_if = require "core.datamodel.if"
local data_attr = require "core.datamodel.attr"
local data_style = require "core.datamodel.style"

local datamodels = {}

local m = {}

function m.create(document, data_table)
    rmlui.DocumentEnableDataModel(document)
    local model = {}
    datamodels[document] = {
        model = model,
        variables = {},
        views = {},
        texts = {},
    }
    local mt = {
        __index = data_table,
    }
    function mt:__call()
        rmlui.DocumentDirtyDataModel(document)
    end
    function mt:__newindex(k, v)
        data_table[k] = v
        rmlui.DocumentDirtyDataModel(document)
    end
    return setmetatable(model, mt)
end

local function collectVariables(datamodel, element, t)
    local vars = datamodel.variables[element]
    if vars then
        for name, value in pairs(vars) do
            if not t[name] then
                t[name] = true
                t[#t+1] = {name, value}
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
    for i = #variables, 1, -1 do
        local t = variables[i]
        s[#s+1] = ("local %s = %s"):format(t[1], t[2])
    end
    return table.concat(s, "\n")
end

m.compileVariables = compileVariables

function m.load(document, element, name, value)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    if name == "data-text" then
        data_text.load(datamodel, element, value)
        return
    end
    local view = datamodel.views[element]
    if not view then
        view = {
            ["for"] = {
                num_elements = 0,
            },
            ["if"] = nil,
            events = {},
            styles = {},
            attributes = {},
            variables = compileVariables(datamodel, element)
        }
        datamodel.views[element] = view
    end
    if name == "data-if" then
        data_if.load(datamodel, view, element, value)
    elseif name == "data-for" then
        data_for.load(datamodel, view, element, value)
    else
        local type, modifier = name:match "^data%-(%a+)%-(.+)$"
        if type == "event" then
            data_event.load(datamodel, view, element, modifier, value)
        elseif type == "style" then
            data_style.load(datamodel, view, element, modifier, value)
        elseif type == "attr" then
            data_attr.load(datamodel, view, element, modifier, value)
        else
            error("unknown data-model attribute:"..name)
        end
    end
end

function m.refresh(document)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    for element, view in pairs(datamodel.views) do
        data_for.refresh(datamodel, element, view)
        data_if.refresh(datamodel, element, view)
        data_event.refresh(datamodel, view)
        data_style.refresh(datamodel, element, view)
        data_attr.refresh(datamodel, element, view)
    end
    data_text.refresh(datamodel)
end

function event.OnDestroyNode(document, node)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    datamodel.variables[node] = nil
    datamodel.texts[node] = nil
    local view = datamodel.views[node]
    if view then
        data_event.destroyNode(view, node)
        datamodel.views[node] = nil
    end
end

function event.OnDocumentCreate(document)
    datamodels[document] = nil
end

function event.OnDocumentDestroy(document)
    local md = datamodels[document]
    if md then
        datamodels[document] = nil
    end
end

return m
