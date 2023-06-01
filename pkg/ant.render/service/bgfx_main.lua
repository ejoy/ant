local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local bgfx = require "bgfx"

local initialized = false

local CALL = {
    "init",
    "set_platform_data",
    "frame",
    "shutdown",
    "request_screenshot",
    "reset",
    "set_debug",

    "encoder_create",
    "encoder_destroy",
    "encoder_frame",
    "maxfps"
}

local SEND = {
    "dbg_text_clear",
    "dbg_text_print",
    "dbg_text_image",
}

local S = {}

function S.CALL()
    return CALL
end

function S.SEND()
    return SEND
end

local profile = {}
local profile_label = {}
local profile_time = 0
local profile_n = 0
local MaxFrame <const> = 30
local MaxText <const> = 10
local MaxName <const> = 48
local profile_printtext = {}

local function profile_print()
    if profile_n ~= MaxFrame then
        profile_n = profile_n + 1
    else
        profile_n = 1

        local r = {}
        for who, time in pairs(profile) do
            r[#r+1] = {who, time}
        end
        table.sort(r, function (a, b)
            return a[2] > b[2]
        end)

        for i = 1, #r do
            local who, time = r[i][1], r[i][2]
            local m = time / MaxFrame * 1000
            local name = ("%s(%d)"):format(profile_label[who], who)
            profile_printtext[i] = name .. (" "):rep(MaxName-#name) .. (" | %.02fms   "):format(m)
            profile[who] = 0
        end
    end

    S.dbg_text_print(0, 3+MaxText, 0x02, "--- encoder")
    for i = 1, #profile_printtext do
        S.dbg_text_print(2, 3+MaxText+i, 0x02, profile_printtext[i])
    end
end

local function profile_init(who, label)
    profile[who] = 0
    profile_label[who] = label or "unk"
end
local function profile_begin()
    profile_print()
    local now = ltask.counter()
    profile_time = now
end
local function profile_end(who)
    local now = ltask.counter()
    profile[who] = profile[who] + (now - profile_time)
end

local encoder = {}
local encoder_num = 0
local encoder_cur = 0
local encoder_frame = 0

function S.encoder_create(label)
    local who = ltask.current_session().from
    encoder[who] = nil
    encoder_num = encoder_num + 1
    profile_init(who, label)
end

function S.encoder_destroy()
    local who = ltask.current_session().from
    if encoder[who] == encoder_frame then
        encoder_cur = encoder_cur - 1
    end
    encoder[who] = nil
    encoder_num = encoder_num - 1
end

function S.encoder_frame()
    local who = ltask.current_session().from
    if encoder[who] ~= encoder_frame then
        encoder[who] = encoder_frame
        encoder_cur = encoder_cur + 1
        profile_end(who)
    end
    return ltask.multi_wait "bgfx.frame"
end

local pause_token
local continue_token

function S.pause()
    if pause_token then
        error "Can't pause twice."
    end
    pause_token = {}
    ltask.wait(pause_token)
    pause_token = nil
end

function S.continue()
    if not continue_token then
        error "Not pause."
    end
    ltask.wakeup(continue_token)
end

function S.frame()
    if not continue_token then
        error "Can only be used in pause."
    end
    return bgfx.frame()
end

local maxfps = 30
local frame_control; do
    local MaxTimeCachedFrame <const> = 1 --*1s
    local frame_first = 1
    local frame_last  = 0
    local frame_time = {}
    local frame_delta = {}
    local fps = 0
    local lasttime = ltask.counter()
    local printtime = 0
    local printtext = ""
    local function clean(time)
        for i = frame_first, frame_last do
            if frame_time[i] < time then
                frame_time[i] = nil
                frame_delta[i] = nil
                frame_first = frame_first + 1
            end
        end
    end
    local function print_fps()
        if frame_first == 1 then
            if frame_last == 1 then
                fps = 0
            else
                fps = frame_last / (frame_time[frame_last] - frame_time[1])
            end
        else
            fps = (frame_last - frame_first + 1) / (MaxTimeCachedFrame)
        end
        if lasttime - printtime >= 1 then
            printtime = lasttime
            if maxfps then
                printtext = ("FPS: %.03f / %d"):format(fps, maxfps)
            else
                printtext = ("FPS: %.03f"):format(fps)
            end
        end
        S.dbg_text_print(0, 0, 0x02, printtext)
    end
    local function print_time()
        local avg = 0
        local max = -math.huge
        local min = math.huge
        for i = frame_first, frame_last do
            local t = frame_delta[i]
            avg = avg + t
            if t > max then
                max = t
            end
            if t < min then
                min = t
            end
        end
        avg = avg / (frame_last - frame_first)
        S.dbg_text_print(0, 1, 0x02, ("avg: %.02fms max:%.02fms min:%.02fms          "):format(avg*1000, max*1000, min*1000))
    end
    function frame_control()
        local time = ltask.counter()
        local delta = time - lasttime
        clean(time - MaxTimeCachedFrame)
        frame_last = frame_last + 1
        frame_time[frame_last] = time
        frame_delta[frame_last] = delta
        print_fps()
        print_time()
        if maxfps and fps > maxfps then
            local waittime = math.ceil((1/maxfps - delta)*1000)
            if waittime > 0 then
                if waittime < 10 then
                    waittime = 10
                end
                exclusive.sleep(waittime)
            end
        end
        lasttime = ltask.counter()
    end
end

function S.maxfps(v)
    if not v or v >= 10 then
        maxfps = v
    end
    return maxfps
end

function S.dbg_text_print(x, y, ...)
    return bgfx.dbg_text_print(x + 16, y + 1, ...)
end

local function mainloop()
    while initialized do
        if encoder_num > 0 and encoder_cur == encoder_num then
            encoder_frame = encoder_frame + 1
            encoder_cur = 0
            local f = bgfx.frame()
            bgfx.dbg_text_clear()
            if pause_token then
                ltask.wakeup(pause_token)
                continue_token = {}
                ltask.wait(continue_token)
                continue_token = nil
            end
            frame_control()
            ltask.multi_wakeup("bgfx.frame", f)
            ltask.sleep(0)
            profile_begin()
        else
            exclusive.sleep(1)
            ltask.sleep(0)
        end
    end
end

local init_token = {}
local thread_num = 0

function S.init(args)
    if init_token == nil then
    elseif args == nil then
        ltask.wait(init_token)
    else
        bgfx.init(args)
        initialized = true
        ltask.fork(mainloop)
        ltask.wakeup(init_token)
        init_token = nil
    end
    thread_num = thread_num + 1
end

function S.shutdown()
    thread_num = thread_num - 1
    if thread_num == 0 then
        initialized = false
        bgfx.shutdown()
    end
end

for _, name in ipairs(CALL) do
    if not S[name] then
        S[name] = bgfx[name]
    end
end

for _, name in ipairs(SEND) do
    if not S[name] then
        S[name] = bgfx[name]
    end
end

return S
