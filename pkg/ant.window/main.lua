local ltask = require "ltask"

local function start(config)
    if config.boot then
        ltask.spawn(config.boot, config)
    end

    local SERVICE_ROOT <const> = 1
    ltask.fork(function ()
        ltask.call(SERVICE_ROOT, "worker_bind", "ant.window|window", 0)
        ltask.uniqueservice "ant.hwi|bgfx"
    end)

    ltask.call(SERVICE_ROOT, "worker_bind", "ant.hwi|bgfx", 1)
    local ServiceWindow = ltask.uniqueservice("ant.window|window", config)
    ltask.call(ServiceWindow, "wait")
end

local function newproxy(t, k)
    local ServiceWindow = ltask.queryservice "ant.window|window"

    local function reboot(initargs)
        ltask.send(ServiceWindow, "reboot", initargs)
    end

    local function set_cursor(cursor)
        ltask.call(ServiceWindow, "set_cursor", cursor)
    end

    local function set_title(title)
        ltask.call(ServiceWindow, "set_title", title)
    end

    t.reboot = reboot
    t.set_cursor = set_cursor
    t.set_title = set_title
    return t[k]
end

return setmetatable({ start = start }, { __index = newproxy })
