local rmlui = require "rmlui"

local m = {}

local function refresh(datamodel, data, element, view_modifier)
    local compiled, err = load(data.script, data.script, "t", datamodel.model)
    if not compiled then
        log.warn(err)
        return
    end
    rmlui.ElementSetProperty(element, view_modifier, compiled())
end

function m.create(datamodel, view, element, view_modifier, view_value)
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
