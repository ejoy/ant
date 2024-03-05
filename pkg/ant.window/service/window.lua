local platform = require "bee.platform"
local world_instance = require "world_instance"

world_instance.init(...)

local S = {}

function S.reboot(args)
    world_instance.reboot(args)
end

function S.wait()
    world_instance.wait()
end

function S.msg(messages)
    world_instance.message(messages)
end

if platform.os == "ios" then
    return S
end

local window = require "window"

function S.set_cursor(cursor)
    window.set_cursor(cursor)
end

function S.set_title(title)
    window.set_title(title)
end

function S.maxfps(fps)
    if window.maxfps then
        window.maxfps(fps)
    end
end

return S
