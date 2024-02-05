local platform = require "bee.platform"
local ltask = require "ltask"
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

local config = ...

local exclusive = require "ltask.exclusive"
local window = require "window"

local message = {}

window.init(message, config.window_size)

ltask.fork(function()
    repeat
        if #message > 0 then
            world_instance.message(message)
            for i = 1, #message do
                message[i] = nil
            end
        end
        exclusive.sleep(1)
        ltask.sleep(0)
    until not window.peek_message()
    if #message > 0 then
        world_instance.message(message)
    end
end)

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
