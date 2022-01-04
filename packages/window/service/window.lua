local ltask = require "ltask"
local exclusive

local S = {}
local event = {
    init = {},
    exit = {},
    size = {},
    mouse_wheel = {},
    mouse = {},
    touch = {},
    keyboard = {},
    char = {},
    update = {},
}

local priority_event = {
    init = {},
    exit = {},
    size = {},
    mouse_wheel = {},
    mouse = {},
    touch = {},
    keyboard = {},
    char = {},
    update = {},
}

for CMD, e in pairs(event) do
    S["send_"..CMD] = function (...)
        for i = 1, #e do
            ltask.send(e[i], CMD, ...)
        end
    end
end

for CMD, e in pairs(event) do
    S["send_"..CMD] = function (...)
        for i = 1, #e do
            ltask.send(e[i], CMD, ...)
        end
    end
end

S["priority_handle"] = function (CMD, ...)
    local headled = false
    local pe = priority_event[CMD]
    for i = 1, #pe do
        headled = ltask.call(pe[i], CMD, ...)
        print("priority_handle", CMD, headled)
        if headled then
            break
        end
    end
    if not headled then
        local e = event[CMD]
        for i = 1, #e do
            ltask.send(e[i], CMD, ...)
        end
    end
end

local function dispatch(CMD,...)
    local SCHEDULE_SUCCESS <const> = 3
    if CMD == "update" then
        repeat
            exclusive.scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    else
        ltask.send(ltask.self(), "priority_handle", CMD, ...)
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

function S.subscribe(...)
    local s = ltask.current_session()
    local param = {...}
    local priority
    if #param > 0 then
        param[1]:gsub("priority=(%w+)", function(match) priority = tonumber(match) end)
    end
    for _, name in ipairs(param) do
        local e = priority and priority_event[name] or event[name]
        if e then
            if not priority then
                e[#e+1] = s.from
            else
                table.insert(e, priority, s.from)
            end
        end
    end
end

local function do_unsubscribe(events, ...)
    local remove = false
    local s = ltask.current_session()
    for _, name in ipairs {...} do
        local e = events[name]
        if e then
            for i, addr in ipairs(e) do
                if addr == s.from then
                    table.remove(e, i)
                    remove = true
                    break
                end
            end
        end
    end
    return remove
end

function S.unsubscribe(...)
    if do_unsubscribe(priority_event, ...) then
        return
    end
    do_unsubscribe(event, ...)
end

local function do_unsubscribe_all(events)
    local remove = false
    local s = ltask.current_session()
    for _, e in pairs(events) do
        for i, addr in ipairs(e) do
            if addr == s.from then
                table.remove(e, i)
                remove = true
                break
            end
        end
    end
end

function S.unsubscribe_all()
    if do_unsubscribe_all(priority_event) then
        return
    end
    do_unsubscribe_all(event)
end

return S
