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


local function refreshElement(datamodel, data)
    local compiled, err = load(data.script, data.script, "t", datamodel.view)
    if not compiled then
        console.warn(err)
        return
    end
    local f = compiled()
    local has_ev = debug.getupvalue(f, 1) == "ev"
    debug.setupvalue(data.callback, 1, f)
    debug.setupvalue(data.callback, 2, has_ev)
end

local function reloadElement(datamodel, element, data)
    local s = {
        "local ev",
        "return function()",
    }
    local vars = datamodel.variables[element]
    if vars then
        for name, value in pairs(vars) do
            s[#s+1] = ("\tlocal %s = %s"):format(name, value)
        end
    end
    s[#s+1] = "\t"..data.value
    s[#s+1] = "end"
    data.script = table.concat(s, "\n")
    refreshElement(datamodel, data)
end

function m.load(datamodel, element, event_type, event_value)
    local data = {}
    datamodel.events[element] = data
    data.value = event_value
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
    reloadElement(datamodel, element, data)
end

function m.setVariable(datamodel, element)
    local data = datamodel.events[element]
    if not data then
        return
    end
    reloadElement(datamodel, element, data)
end

function m.refresh(datamodel)
    for _, data in pairs(datamodel.events) do
        refreshElement(datamodel, data)
    end
end

function m.destroyNode(datamodel, element)
    local data = datamodel.events[element]
    if not data then
        return
    end
    rmlui.ElementRemoveEventListener(element, data.listener)
    datamodel.events[element] = nil
end

return m
