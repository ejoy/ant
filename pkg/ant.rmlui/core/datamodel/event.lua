local rmlui = require "rmlui"
local console = require "core.sandbox.console"
local constructor = require "core.DOM.constructor"

local m = {}

local function invoke(f, ...)
	local ok, err = xpcall(f, function(msg)
		return debug.traceback(msg)
	end, ...)
	if not ok then
		console.warn(err)
	end
	return ok, err
end

local function refresh(datamodel, data)
    local compiled, err = load(data.script, data.script, "t", datamodel.data_table)
    if not compiled then
        console.warn(err)
        return
    end
    local f = compiled()
    local has_ev = debug.getupvalue(f, 1) == "ev"
    debug.setupvalue(data.callback, 1, f)
    debug.setupvalue(data.callback, 2, has_ev)
end

function m.load(datamodel, view, element, event_type, event_value)
    local data = view.events[event_type]
    if not data then
        data = {}
        view.events[event_type] = data
        local f
        local has_ev
        data.callback = function (e)
            local func = f
            if has_ev then
                debug.setupvalue(func, 1, constructor.Event(e))
            end
            invoke(func)
        end
        data.listener = rmlui.ElementAddEventListener(element, event_type, data.callback)
    end
    local s = {
        "local ev",
        "return function()",
        view.variables,
        event_value,
        "end",
    }
    data.script = table.concat(s, "\n")
    refresh(datamodel, data)
end

function m.refresh(datamodel, view)
    for _, data in pairs(view.events) do
        refresh(datamodel, data)
    end
end

function m.destroyNode(view, element)
    for _, data in pairs(view.events) do
        rmlui.ElementRemoveEventListener(element, data.listener)
    end
end

return m
