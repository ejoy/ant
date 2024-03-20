local ltask = require "ltask"

local function start(config)
    if config.boot then
        --ltask.spawn(config.boot, config)
    end

    ltask.spawn_service {
        unique = true,
        name = "ant.hwi|bgfx",
        worker_id = 1,
    }
    local ServiceWindow = ltask.spawn_service {
        unique = true,
        name = "ant.window|window",
        args = { config },
        worker_id = 0,
    }
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
