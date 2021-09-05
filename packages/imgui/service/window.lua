local ltask = require "ltask"
local event = {
    init = {},
    exit = {},
    size = {},
    mouse_wheel = {},
    mouse = {},
    touch = {},
    keyboard = {},
    update = {},
}

local S = {}

for name in pairs(event) do
    local e = event[name]
    S[name] = function (...)
        for i = 1, #e do
            ltask.send(e[i], name, ...)
        end
    end
end

function S.subscribe(...)
    local s = ltask.current_session()
    for _, name in ipairs {...} do
        local e = event[name]
        if e then
            e[#e+1] = s.from
        end
    end
end

function S.unsubscribe(...)
    local s = ltask.current_session()
    for _, name in ipairs {...} do
        local e = event[name]
        if e then
            for i, addr in ipairs(e) do
                if addr == s.from then
                    table.remove(e, i)
                    break
                end
            end
        end
    end
end

function S.unsubscribe_all()
    local s = ltask.current_session()
    for _, e in pairs(event) do
        for i, addr in ipairs(e) do
            if addr == s.from then
                table.remove(e, i)
                break
            end
        end
    end
end

return S
