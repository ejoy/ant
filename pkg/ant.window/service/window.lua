local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local platform = require "bee.platform"

local WindowModePeek <const> = 0
local WindowModeLoop <const> = 1
local WindowMode <const> = {
    windows = WindowModePeek,
    android = WindowModePeek,
    ios = WindowModeLoop,
}

local function init()
    if platform.os == "ios" then
        local gesture = require "ios.gesture"
        gesture.tap {}
        gesture.pinch {}
        gesture.long_press {}
        gesture.pan {}
    end
end

local message = {}
local quit = false

local function message_loop(update)
    local ServiceWorld = ltask.queryservice "ant.window|world"
    init()
    while not quit do
        if #message > 0 then
            ltask.send(ServiceWorld, "msg", message)
            for i = 1, #message do
                message[i] = nil
            end
        end
        if update then
            ltask.wait "update"
        else
            ltask.sleep(0)
        end
    end
    if #message > 0 then
        ltask.send(ServiceWorld, "msg", message)
    end
end

local S = {}

local function create_peek_window()
    local window = require "window"
    window.init(message)
    ltask.fork(message_loop, false)
    ltask.fork(function()
        repeat
            exclusive.sleep(0)
            ltask.sleep(0)
        until not window.peekmessage()
        quit = true
    end)
end

local function create_loop_window()
    local scheduling = exclusive.scheduling()
    local window = require "window"
    local function update()
        local SCHEDULE_SUCCESS <const> = 3
        ltask.wakeup "update"
        repeat
            scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    end
    window.init(message, update)
    ltask.fork(message_loop, true)
    ltask.fork(function()
        window.mainloop()
    end)
end

if WindowMode[platform.os] == WindowModePeek then
    S.create_window = create_peek_window
elseif WindowMode[platform.os] == WindowModeLoop then
    S.create_window = create_loop_window
else
    error "window service unimplemented"
end

return S
