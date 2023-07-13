local rmlui = require "rmlui"
local console = require "core.sandbox.console"

local m = {}

local function refresh(datamodel, data, element, name)
    local compiled, err = load(data.script, data.script, "t", datamodel.model)
    if not compiled then
        console.warn(err)
        return
    end
    local res = compiled()
    if name == "id" then
        rmlui.ElementSetId(element, res)
    elseif name == "class" then
        rmlui.ElementSetClassName(element, res)
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
