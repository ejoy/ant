local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local window = require "window"

local SCHEDULE_SUCCESS <const> = 3

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
}

local function dispatch(CMD,...)
    if CMD == "update" then
        repeat
            exclusive.scheduling()
        until ltask.schedule_message() ~= SCHEDULE_SUCCESS
    else
        local e = event[CMD]
        for i = 1, #e do
            ltask.send(e[i], CMD, ...)
        end
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

function S.init()
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
    for _, name in ipairs {...} do
        local e = event[name]
        if e then
            e[#e+1] = s.from
        end
    end
end

function S.unsubscribe(...)
    local s = ltask.current_session()
    for _, name in ipairs {...} do
        local e = event[name]
        if e then
            for i, addr in ipairs(e) do
                if addr == s.from then
                    table.remove(e, i)
                    break
                end
            end
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
