local _events = {}
local ev = {}

function ev.emit(name, ...)
    local event = _events[name]
    if event then
        for i = 1, #event do
            event[i](...)
        end
    end
end

function ev.on(name, f)
    local event = _events[name]
    if event then
        event[#event+1] = f
    else
        _events[name] = {f}
    end
end

return ev
