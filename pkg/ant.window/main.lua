local function start(initargs)
    local exclusive = { "ant.window|window", "timer", "ant.hwi|bgfx" }
    if not __ANT_RUNTIME__ then
        exclusive[#exclusive+1] = "subprocess"
    end
    dofile "/engine/ltask.lua" {
        bootstrap = { "ant.window|boot", initargs },
        exclusive = exclusive,
    }
end

local function newproxy(t, k)
    local ltask = require "ltask"
    local ServiceWorld = ltask.queryservice "ant.window|world"
    local ServiceWindow = ltask.queryservice "ant.window|window"

    local function reboot(initargs)
        ltask.send(ServiceWorld, "reboot", initargs)
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