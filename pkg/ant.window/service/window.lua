local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local platform = require "bee.platform"
local SupportGesture <const> = platform.os == "ios"
local scheduling

local S = {}

local event = {
    init = {},
    exit = {},
    size = {},
    mouse_wheel = {},
    mouse = {},
    touch = {},
    gesture = {},
    keyboard = {},
    char = {},
}

local SCHEDULE_SUCCESS <const> = 3

local CMD = {}
local queue = {}
local noempty = {}

for cmd in pairs(event) do
    CMD[cmd] = function (...)
        queue[#queue+1] = table.pack(cmd, ...)
        if #queue == 1 then
            ltask.wakeup(noempty)
        end
    end
end

local function dispatch(cmd,...)
    CMD[cmd](...)
end

local quit = false

local function call_event(cmd, ...)
    local user = event[cmd]
    for i = 1, #user do
        if ltask.call(user[i], cmd, ...) then
            break
        end
    end
    quit = (cmd == "exit")
end

local function messageloop(...)
    local event_init = event.init
    for i = 1, #event_init do
        if ltask.call(event_init[i], 'init', ...) then
            return
        end
    end
    while not quit do
        if #queue == 0 then
            ltask.wait(noempty)
        else
            local q = queue
            queue = {}
            for k = 1, #q do
                local e = q[k]
                call_event(table.unpack(e, 1, e.n))
            end
        end
    end
    ltask.multi_wakeup "quit"
end

if SupportGesture then
    local gesture = require "ios.gesture"
    local function gesture_init()
        gesture.tap {}
        gesture.pinch {}
        gesture.long_press {}
        gesture.pan {}
    end
    local function gesture_dispatch(name, ...)
        if not name then
            return
        end
        CMD.gesture(name, ...)
        return true
    end
    function CMD.init(...)
        ltask.fork(function (...)
            gesture_init()
            messageloop(...)
        end, ...)
    end
    function CMD.update()
        while gesture_dispatch(gesture.event()) do
        end
        repeat
            scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    end
else
    function CMD.init(...)
        ltask.fork(messageloop, ...)
    end
    function CMD.update()
        repeat
            scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    end
end

local function ios_init()
    local ServiceWorld = ltask.queryservice "ant.window|world"
    for _, v in pairs(event) do
        v[1] = ServiceWorld
    end
    ltask.fork(function ()
        local ServiceRmlui = ltask.queryservice "ant.rmlui|rmlui"
        for _, e in ipairs {"mouse", "touch", "gesture"} do
            table.insert(event[e], 1, ServiceRmlui)
        end
    end)
    local exclusive = require "ltask.exclusive"
    scheduling = exclusive.scheduling()
    local window = require "window"
    local handle = window.init(dispatch)
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
