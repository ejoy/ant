local _events = {}

local mt = {}

function mt:__newindex(name, f)
    local event = _events[name]
    if event then
        event[#event+1] = f
    else
        _events[name] = {f}
    end
end

function mt:__call(name, ...)
    local event = _events[name]
    if event then
        for i = 1, #event do
            event[i](...)
        end
    end
end

return setmetatable({}, mt)
