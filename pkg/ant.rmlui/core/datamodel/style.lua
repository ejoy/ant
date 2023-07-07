local rmlui = require "rmlui"
local console = require "core.sandbox.console"

local m = {}

local function eval(datamodel, data)
    local compiled, err = load(data.script, data.script, "t", datamodel.model)
    if not compiled then
        console.warn(err)
        return
    end
    return compiled()
end

local function refresh(datamodel, data, element, view_modifier)
    local res = eval(datamodel, data)
    rmlui.ElementSetProperty(element, view_modifier, res)
end

function m.load(datamodel, view, element, view_modifier, view_value)
    local data = view.styles[view_modifier]
    if not data then
        data = {}
        view.styles[view_modifier] = data
    end
    data.script = view.variables.."\nreturn "..view_value
    refresh(datamodel, data, element, view_modifier)
end

function m.refresh(datamodel, element, view)
    for view_modifier, data in pairs(view.styles) do
        refresh(datamodel, data, element, view_modifier)
    end
end

return m
