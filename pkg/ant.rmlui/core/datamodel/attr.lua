local rmlui = require "rmlui"

local m = {}

local function insertClassName(classes, name)
    if not classes[name] then
        return
    end
    classes[name] = true
    classes[#classes+1] = name
end

local function computeClassName(classes, data)
    for k, v in pairs(data) do
        if type(k) == "string" and v == true then
            insertClassName(classes, k)
        elseif type(k) == "number" then
            if type(v) == "string" then
                insertClassName(classes, v)
            elseif type(v) == "table" then
                computeClassName(classes, v)
            end
        end
    end
    return classes
end

local function refresh(datamodel, data, element, name)
    local compiled, err = load(data.script, data.script, "t", datamodel.model)
    if not compiled then
        log.warn(err)
        return
    end
    local res = compiled()
    if name == "id" then
        rmlui.ElementSetId(element, res)
    elseif name == "class" then
        if type(res) == "table" then
            local classes = computeClassName({}, data)
            rmlui.ElementSetClassName(element, table.concat(classes, " "))
        else
            rmlui.ElementSetClassName(element, res)
        end
    elseif name == "style" then
        for k, v in pairs(res) do
            rmlui.ElementSetProperty(element, k, v)
        end
    else
        rmlui.ElementSetAttribute(element, name, res)
    end
end

function m.create(datamodel, view, element, view_modifier, view_value)
    local data = view.attributes[view_modifier]
    if not data then
        data = {}
        view.attributes[view_modifier] = data
    end
    data.script = view.variables.."\nreturn "..view_value
    refresh(datamodel, data, element, view_modifier)
end

function m.refresh(datamodel, element, view)
    for view_modifier, data in pairs(view.attributes) do
        refresh(datamodel, data, element, view_modifier)
    end
end

return m
