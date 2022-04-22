local ltask = require "ltask"
local gesture
local exclusive

local S = {}

local priority = {}
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
    update = {},
}

for CMD, e in pairs(event) do
    S["send_"..CMD] = function (...)
        for i = 1, #e do
            if ltask.call(e[i], CMD, ...) then
                return
            end
        end
    end
end

local function gesture_init()
    gesture = require "gesture"
    gesture.tap {
        name = "tap"
    }
end

local function gesture_dispatch(name, ...)
    if not name then
        return
    end
    ltask.send(ltask.self(), "send_gesture", name, ...)
    return true
end

local function dispatch(CMD,...)
    local SCHEDULE_SUCCESS <const> = 3
    if CMD == "update" then
        if gesture then
            while gesture_dispatch(gesture.event()) do
            end
        end
        repeat
            exclusive.scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    else
        if CMD == "init" then
            if require "platform".OS == "iOS" then
                gesture_init()
            end
        end
        ltask.send(ltask.self(), "send_"..CMD, ...)
    end
end

local tokenmap = {}
local function multi_wait(key)
	local mtoken = tokenmap[key]
	if not mtoken then
		mtoken = {}
		tokenmap[key] = mtoken
	end
	local t = {}
	mtoken[#mtoken+1] = t
	return ltask.wait(t)
end

local function multi_wakeup(key, ...)
	local mtoken = tokenmap[key]
	if mtoken then
		tokenmap[key] = nil
		for _, token in ipairs(mtoken) do
			ltask.wakeup(token, ...)
		end
	end
end

function S.create_window()
    exclusive = require "ltask.exclusive"
    local window = require "window"
    window.create(dispatch, 1334, 750)
    ltask.fork(function()
        window.mainloop(true)
        multi_wakeup "quit"
    end)
end

function S.wait()
    multi_wait "quit"
end

function S.priority(v)
    local s = ltask.current_session()
    priority[s] = v
end

local function insert(t, s)
    local function get_priority(ss)
        return priority[ss] or 0
    end
    local p = get_priority(s)
    for i = #t, 1, -1 do
        if p <= get_priority(t[i]) then
            table.insert(t, i, s)
            return
        end
    end
    table.insert(t, s)
end

function S.subscribe(events)
    local s = ltask.current_session()
    for _, name in ipairs(events) do
        local e = event[name]
        if e then
            insert(e, s.from)
        end
    end
end

function S.unsubscribe_all()
    local s = ltask.current_session()
    for _, e in pairs(event) do
        for i, addr in ipairs(e) do
            if addr == s.from then
                table.remove(e, i)
                break
            end
        end
    end
end

return S
