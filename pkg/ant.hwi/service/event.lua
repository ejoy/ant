local ltask = require "ltask"

local events = {}
local quit

ltask.fork(function ()
    local bgfx = require "bgfx"
    local hwi = import_package "ant.hwi"
    hwi.init_bgfx()
    bgfx.init()
    bgfx.encoder_create "event"
    while not quit do
        events = {}
        bgfx.encoder_frame()
    end
    bgfx.shutdown()
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

function S.quit()
    quit = {}
    ltask.wait(quit)
    ltask.quit()
end

return S
