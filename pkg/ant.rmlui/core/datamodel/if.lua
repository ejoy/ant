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

local function refresh(datamodel, data, element)
    local res = eval(datamodel, data)
    rmlui.ElementSetVisible(element, res)
end

function m.load(datamodel, view, element, view_value)
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
