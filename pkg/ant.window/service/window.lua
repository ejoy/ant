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

local function create_peek_window(size)
    local window = require "window"
    window.init(message, size)
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
        until not window.peekmessage()
        if #message > 0 then
            ltask.send(ServiceWorld, "msg", message)
        end
    end)
end

local function create_loop_window(size)
    local scheduling = exclusive.scheduling()
    local window = require "window"
    local SCHEDULE_SUCCESS <const> = 3
    local CALL = false
    local function update()
        ltask.wakeup "update"
        repeat
            scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
        while CALL do
            exclusive.sleep(1)
            repeat
                scheduling()
            until ltask.schedule_message() ~= SCHEDULE_SUCCESS
        end
    end
    window.init(message, size, update)
    ltask.fork(function ()
        local ServiceWorld = ltask.queryservice "ant.window|world"
        while true do
            if #message > 0 then
                local mq = {}
                for i = 1, #message do
                    mq[i] = message[i]
                    message[i] = nil
                end
                CALL = true
                ltask.call(ServiceWorld, "msg", mq)
                CALL = false
            end
            ltask.wait "update"
        end
    end)
    ltask.fork(function()
        window.mainloop()
        update()
    end)
end

local S = {}

function S.start(config)
	if WindowMode[platform.os] == WindowModePeek then
		create_peek_window(config.window_size)
	elseif WindowMode[platform.os] == WindowModeLoop then
		create_loop_window(config.window_size)
	else
		error "window service unimplemented"
	end
end

function S.maxfps(fps)
    local window = require "window"
    if window.maxfps then
        window.maxfps(fps)
    end
end

function S.setcursor(cursor)
    local window = require "window"
    if window.setcursor then
        window.setcursor(cursor)
    end
end

return S
