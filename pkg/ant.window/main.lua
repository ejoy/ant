local function start(initargs)
    local platform = require "bee.platform"
    if platform.os == "ios" then
        dofile "/engine/ltask.lua" {
            bootstrap = { "ant.window|ios_boot", initargs },
            exclusive = { "ant.window|ios_window", "timer", "ant.hwi|bgfx" },
        }
        return
    end
    local exclusive = { { "ant.window|world", initargs }, "timer", "ant.hwi|bgfx" }
    if not __ANT_RUNTIME__ then
        exclusive[#exclusive+1] = "subprocess"
    end
    dofile "/engine/ltask.lua" {
        bootstrap = { "ant.window|boot" },
        exclusive = exclusive,
    }
end

local function newproxy(t, k)
    local ltask = require "ltask"
    local ServiceWorld = ltask.queryservice "ant.window|world"

    local function reboot(initargs)
        ltask.send(ServiceWorld, "reboot", initargs)
    end

    local function set_cursor(cursor)
        ltask.call(ServiceWorld, "set_cursor", cursor)
    end

    local function set_title(title)
        ltask.call(ServiceWorld, "set_title", title)
    end

    t.reboot = reboot
    t.set_cursor = set_cursor
    t.set_title = set_title
    return t[k]
end

return setmetatable({ start = start }, { __index = newproxy })