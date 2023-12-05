local eventListener = require "core.event.listener"

local m = {}

local function invoke(f, ...)
	local ok, err = xpcall(f, function(msg)
		return debug.traceback(msg)
	end, ...)
	if not ok then
		log.warn(err)
	end
	return ok, err
end

local function findUpValue(f, name)
    local i = 1
    while true do
        local v = debug.getupvalue(f, i)
        if v == nil then
            return
        end
        if v == name then
            return i
        end
        i = i + 1
    end
end

local function updateUpValue(f, t)
    local i = 1
    while true do
        local v = debug.getupvalue(f, i)
        if v == nil then
            return
        end
        if t[v] ~= nil then
            debug.setupvalue(f, i, t[v])
        end
        i = i + 1
    end
end

local function refresh(datamodel, data)
    local compiled, err = load(data.script, data.script, "t", datamodel.model)
    if not compiled then
        log.warn(err)
        return
    end
    local f = compiled()
    local ev = findUpValue(f, "ev")
    updateUpValue(data.callback, {
        f = f,
        ev = ev,
    })
end

function m.create(datamodel, view, document, element, event_type, event_value)
    local data = view.events[event_type]
    if not data then
        data = {}
        view.events[event_type] = data
        local f
        local ev
        data.callback = function (e)
            local func = f
            if ev then
                debug.setupvalue(func, ev, e)
            end
            invoke(func)
        end
        data.listener = eventListener.add(document, element, event_type, data.callback)
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

return m
