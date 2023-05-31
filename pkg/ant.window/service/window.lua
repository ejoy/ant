local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local platform = require "bee.platform"

local WindowModePeek <const> = 0
local WindowModeLoop <const> = 1
local WindowMode <const> = {
    windows = WindowModePeek,
    android = WindowModePeek,
    macos = WindowModePeek,
    ios = WindowModeLoop,
}

local message = {}

local function create_peek_window()
    local window = require "window"
    window.init(message)
    ltask.fork(function()
        local ServiceWorld = ltask.queryservice "ant.window|world"
        repeat
            if #message > 0 then
                ltask.send(ServiceWorld, "msg", message)
                for i = 1, #message do
                    message[i] = nil
                end
            end
            exclusive.sleep(0)
            ltask.sleep(0)
        until not window.peekmessage()
        if #message > 0 then
            ltask.send(ServiceWorld, "msg", message)
        end
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
    ltask.fork(function ()
        local ServiceWorld = ltask.queryservice "ant.window|world"
        while true do
            if #message > 0 then
                ltask.send(ServiceWorld, "msg", message)
                for i = 1, #message do
                    message[i] = nil
                end
            end
            ltask.wait "update"
        end
    end)
    ltask.fork(function()
        window.mainloop()
        update()
    end)
end

if WindowMode[platform.os] == WindowModePeek then
    create_peek_window()
elseif WindowMode[platform.os] == WindowModeLoop then
    create_loop_window()
else
    error "window service unimplemented"
end

return {}
