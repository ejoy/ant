local ltask = require "ltask"

local function start(initargs)
    if not __ANT_RUNTIME__ then
        ltask.spawn("ant.window|boot", initargs)
        return
    end
    local boot = dofile "/engine/ltask.lua"
    local config = {
        bootstrap = {
            ["ant.window|boot"] = {
                args = {initargs},
                unique = false,
            }
        },
        worker = 6,
    }
    local platform = require "bee.platform"
    if platform.os == "ios" then
        local window = require "window.ios"
        window.mainloop(function (what)
            if what == "init" then
                boot:start(config)
            elseif what == "exit" then
                boot:wait()
            end
        end)
        return
    end
    config.mainthread = 0
    boot:start(config)
    boot:wait()
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
