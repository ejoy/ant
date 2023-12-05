local rmlui = require "rmlui"

local m = {}

local function refresh(datamodel, data, element)
    local compiled, err = load(data.script, data.script, "t", datamodel.model)
    if not compiled then
        log.warn(err)
        return
    end
    rmlui.ElementSetVisible(element, compiled())
end

function m.create(datamodel, view, element, view_value)
    local data = view["if"]
    if not data then
        data = {}
        view["if"] = data
    end
    data.script = view.variables.."\nreturn "..view_value
    refresh(datamodel, data, element)
end

function m.refresh(datamodel, element, view)
    local data = view["if"]
    if data then
        refresh(datamodel, data, element)
    end
end

return m
