local ltask = require "ltask"

local events = {}

ltask.fork(function ()
    local bgfx = require "bgfx"
    local hwi = import_package "ant.hwi"
    hwi.init_bgfx()
    bgfx.encoder_create "event"
    while true do
        events = {}
        bgfx.encoder_frame()
    end
end)

local S = {}

function S.set(name, ...)
    local ev = events[name]
    if not ev then
        ev = {}
        events[name] = ev
    end
    if ev.data then
        error(("event `%s` repeat set"):format(name))
    end
    ev.data = table.pack(...)
    if ev.token then
        ltask.multi_wakeup(ev.token)
    end
end

function S.wait(name)
    local ev = events[name]
    if not ev then
        ev = {}
        events[name] = ev
    end
    if not ev.data then
        if not ev.token then
            ev.token = {}
        end
        ltask.multi_wait(ev.token)
    end
    return table.unpack(ev.data, 1, ev.data.n)
end

return S
