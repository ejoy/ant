local rmlui = require "rmlui"
local console = require "core.sandbox.console"

local m = {}

local function eval(datamodel, data)
    local compiled, err = load(data.script, data.script, "t", datamodel.data_table)
    if not compiled then
        console.warn(err)
        return
    end
    return compiled()
end

local function refresh(datamodel, data, element, view_type, view_modifier)
    local res = eval(datamodel, data)
    if view_type == "style" then
        rmlui.ElementSetProperty(element, view_modifier, res)
    elseif view_type == "attr" then
        rmlui.ElementSetAttribute(element, view_modifier, res)
    elseif view_type == "if" then
        rmlui.ElementSetVisible(element, res)
    end
end

function m.load(datamodel, view, element, view_type, view_modifier, view_value)
    local data = view.modifiers[view_type][view_modifier]
    if not data then
        data = {}
        view.modifiers[view_type][view_modifier] = data
    end
    local s = {
        view.variables,
        "return "..view_value,
    }
    data.script = table.concat(s, "\n")
    refresh(datamodel, data, element, view_type, view_modifier)
end

function m.refresh(datamodel, element, view)
    for view_type, t in pairs(view.modifiers) do
        for view_modifier, data in pairs(t) do
            refresh(datamodel, data, element, view_type, view_modifier)
        end
    end
end

return m
