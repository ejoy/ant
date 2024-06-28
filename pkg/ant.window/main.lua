local ltask = require "ltask"

local function start(config)
    local function spawn_window()
        local ServiceWindow = ltask.spawn_service {
            unique = true,
            name = "ant.window|window",
            args = { config },
            worker_id = 0,
        }
        ltask.call(ServiceWindow, "wait")
    end
    local function spawn_bgfx()
        ltask.spawn_service {
            unique = true,
            name = "ant.hwi|bgfx",
            worker_id = 1,
        }
    end
    local function spawn_rmlui()
        ltask.uniqueservice "ant.rmlui|rmlui"
    end
    local function spawn_resource()
        ltask.uniqueservice "ant.resource_manager|resource"
    end
    for _, resp in ltask.parallel {
        { spawn_window },
        { spawn_bgfx },
        { spawn_rmlui },
        { spawn_resource },
    } do
        if resp.error then
            resp:rethrow()
        end
    end
end

local function newproxy(t, k)
    local ServiceWindow = ltask.queryservice "ant.window|window"

    local function reboot(initargs)
        ltask.send(ServiceWindow, "reboot", initargs)
    end

    local function set_cursor(cursor)
        ltask.call(ServiceWindow, "set_cursor", cursor)
    end

    local function show_cursor(show)
        ltask.call(ServiceWindow, "show_cursor", show)
    end

    local function set_title(title)
        ltask.call(ServiceWindow, "set_title", title)
    end

    local function set_fullscreen(fullscreen)
        ltask.call(ServiceWindow, "set_fullscreen", fullscreen)
    end

    t.reboot = reboot
    t.set_cursor = set_cursor
    t.show_cursor = show_cursor
    t.set_title = set_title
    t.set_fullscreen = set_fullscreen
	
	function t.get_cmd()
		return ltask.call(ServiceWindow, "get_cmd")
	end
	
    return t[k]
end

return setmetatable({ start = start }, { __index = newproxy })
