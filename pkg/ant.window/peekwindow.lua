local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local window = require "window"

local message = {}

local S = {}

function S.start(config)
    window.init(message, config.window_size)
    ltask.fork(function()
        local ServiceWorld = ltask.queryservice "ant.window|world"
        repeat
            if #message > 0 then
                ltask.send(ServiceWorld, "msg", message)
                for i = 1, #message do
                    message[i] = nil
                end
            end
            exclusive.sleep(1)
            ltask.sleep(0)
        until not window.peek_message()
        if #message > 0 then
            ltask.send(ServiceWorld, "msg", message)
        end
    end)
end

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
