local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local platform = require "bee.platform"
local SupportGesture <const> = platform.os == "ios"

local S = {}
local quit = false
local function ios_init()
    local exclusive = require "ltask.exclusive"
    local scheduling = exclusive.scheduling()
    local window = require "window"
    local message = {}
    local function update()
        local SCHEDULE_SUCCESS <const> = 3
        ltask.wakeup "update"
        repeat
            scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    end
    local handle = window.init(message, update)
    ltask.fork(function ()
        local ServiceWorld = ltask.queryservice "ant.window|world"
        assert(#message > 0 and message[1][1] == "init")
        local init = table.remove(message, 1)
        ltask.call(ServiceWorld, table.unpack(init, 1, init.n))

        if SupportGesture then
            local gesture = require "ios.gesture"
            local function gesture_init()
                gesture.tap {}
                gesture.pinch {}
                gesture.long_press {}
                gesture.pan {}
            end
            gesture_init()
        end

        while not quit do
            if #message > 0 then
                ltask.send(ServiceWorld, "msg", message)
                for i = 1, #message do
                    message[i] = nil
                end
            end
            ltask.wait "update"
        end
        if #message > 0 then
            ltask.send(ServiceWorld, "msg", message)
        end
        ltask.call(ServiceWorld, "exit")
        ltask.multi_wakeup "quit"
    end)
    ltask.fork(function()
        window.mainloop(handle, true)
    end)
end

local function windows_init()
    local window = require "window"
    local message = {}
    local quit = false
    window.init(message)
    ltask.fork(function()
        local ServiceWorld = ltask.queryservice "ant.window|world"
        assert(#message > 0 and message[1][1] == "init")
        local init = table.remove(message, 1)
        ltask.call(ServiceWorld, table.unpack(init, 1, init.n))
        while not quit do
            if #message > 0 then
                ltask.send(ServiceWorld, "msg", message)
                for i = 1, #message do
                    message[i] = nil
                end
            end
            ltask.sleep(0)
        end
        if #message > 0 then
            ltask.send(ServiceWorld, "msg", message)
        end
        ltask.call(ServiceWorld, "exit")
        ltask.multi_wakeup "quit"
    end)
    ltask.fork(function()
        repeat
            exclusive.sleep(0)
            ltask.sleep(0)
        until not window.peekmessage()
        quit = true
    end)
end

if platform.os == "windows" then
    S.create_window = windows_init
else
    S.create_window = ios_init
end

function S.wait()
    ltask.multi_wait "quit"
end

return S
