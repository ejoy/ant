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
    local model = {}
    local datamodel = {
        model = model,
        variables = {},
        views = {},
        texts = {},
        data_for = {},
        create_queue = {},
        dirty = true,
    }
    datamodels[document] = datamodel
    local mt = {
        __index = data_table,
    }
    function mt:__call()
        datamodel.dirty = true
    end
    function mt:__newindex(k, v)
        data_table[k] = v
        datamodel.dirty = true
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

local function InDataFor(datamodel, node)
    while true do
        if datamodel.data_for[node] then
            return true
        end
        node = rmlui.NodeGetParent(node)
        if node == nil then
            return false
        end
    end
end

local NodeTypeElement <const> = 1
local NodeTypeText    <const> = 2

function event.OnCreateElement(document, element)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    local create_queue = datamodel.create_queue
    create_queue[element] = NodeTypeElement
    create_queue[#create_queue+1] = element
end

function event.OnCreateText(document, node)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    local create_queue = datamodel.create_queue
    create_queue[node] = NodeTypeText
    create_queue[#create_queue+1] = node
end

local function OnCreateElement(datamodel, document, element)
    local attributes = rmlui.ElementGetAttributes(element)
    if attributes["data-for"] then
        rmlui.ElementSetVisible(element, false)
        rmlui.ElementRemoveAttribute(element, "data-for")
        local view = datamodel.data_for[element]
        if not view then
            view = {
                num_elements = 0,
                variables = compileVariables(datamodel, element),
            }
            datamodel.data_for[element] = view
            table.insert(datamodel.data_for, element)
        end
        data_for.create(datamodel, view, element, attributes["data-for"])
    else
        for name, value in pairs(attributes) do
            if name:match "^data-" then
                local view = datamodel.views[element]
                if not view then
                    view = {
                        ["if"] = nil,
                        events = {},
                        styles = {},
                        attributes = {},
                        variables = compileVariables(datamodel, element),
                    }
                    datamodel.views[element] = view
                end
                if name == "data-if" then
                    data_if.create(datamodel, view, element, value)
                else
                    local type, modifier = name:match "^data%-(%a+)%-(.+)$"
                    if type == "event" then
                        data_event.create(datamodel, view, document, element, modifier, value)
                    elseif type == "style" then
                        data_style.create(datamodel, view, element, modifier, value)
                    elseif type == "attr" then
                        data_attr.create(datamodel, view, element, modifier, value)
                    else
                        error("unknown data-model attribute:"..name)
                    end
                end
            end
        end
    end
end

local function OnCreateText(datamodel, node)
    data_text.create(datamodel, node)
end

local function OnUpdate(datamodel, document)
    local create_queue = datamodel.create_queue
    if #create_queue > 0 then
        datamodel.create_queue = {}
        for _, node in ipairs(create_queue) do
            local type = create_queue[node]
            if type == NodeTypeElement then
                if not InDataFor(datamodel, node) then
                    OnCreateElement(datamodel, document, node)
                end
            elseif type == NodeTypeText then
                if not InDataFor(datamodel, node) then
                    OnCreateText(datamodel, node)
                end
            end
        end
    end
end

local function OnRefresh(datamodel)
    for _, element in ipairs(datamodel.data_for) do
        data_for.refresh(datamodel, element, datamodel.data_for[element])
    end
    for element, view in pairs(datamodel.views) do
        data_if.refresh(datamodel, element, view)
        data_event.refresh(datamodel, view)
        data_style.refresh(datamodel, element, view)
        data_attr.refresh(datamodel, element, view)
    end
    data_text.refresh(datamodel)
end

function m.update(document)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    for _ = 1, 10 do
        OnUpdate(datamodel, document)
        if not datamodel.dirty then
            break
        end
        datamodel.dirty = false
        OnRefresh(datamodel)
        if not datamodel.dirty then
            break
        end
    end
end

function event.OnDestroyNode(document, node)
    local datamodel = datamodels[document]
    if not datamodel then
        return
    end
    datamodel.create_queue[node] = nil
    datamodel.variables[node] = nil
    datamodel.texts[node] = nil
    if datamodel.data_for[node] then
        datamodel.data_for[node] = nil
        for i, v in ipairs(datamodel.data_for) do
            if v == node then
                table.remove(datamodel.data_for, i)
                break
            end
        end
    end
    datamodel.views[node] = nil
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
