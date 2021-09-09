dofile "engine/common/init_bgfx.lua"
local ltask = require "ltask"
local exclusive = require "ltask.exclusive"
local bgfx = require "bgfx"

local APIS = {
    "init",
    "dbg_text_clear",
    "dbg_text_print",
    "dbg_text_image",
    "frame",
    "shutdown",
    "request_screenshot",
    "reset",
    "set_debug",

    "encoder_frame",
    "maxfps"
}
local S = {}

function S.APIS()
    return APIS
end

local encoder = {}
local encoder_num = 0
local encoder_cur = 0
local encoder_frame = 0

local tokens = {}
local function wait_frame()
    local t = {}
    tokens[#tokens+1] = t
    ltask.wait(t)
end
local function wakeup_frame(...)
    for i, token in ipairs(tokens) do
        ltask.wakeup(token, ...)
        tokens[i] = nil
    end
end

function S.encoder_init()
    local who = ltask.current_session().from
    encoder[who] = nil
    encoder_num = encoder_num + 1
end

function S.encoder_release()
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
    end
    return wait_frame()
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
    local MaxTimeCachedFrame <const> = 1000 --*10ms
    local frame_first = 1
    local frame_last  = 0
    local frames = {}
    local fps = 0
    local lasttime = 0
    local function gettime()
        local _, t = ltask.now() --10ms
        return t
    end
    local function clean(time)
        for i = frame_first, frame_last do
            if frames[i] < time then
                frames[i] = nil
                frame_first = frame_first + 1
            end
        end
    end
    local function calc_fps()
        if frame_first == 1 then
            if frame_last == 1 then
                fps = 0
            else
                fps = frame_last / (frames[frame_last] - frames[1]) * 100
            end
        else
            fps = (frame_last - frame_first + 1) / (MaxTimeCachedFrame / 100)
        end
    end
    local function print_fps()
        if maxfps then
            print(("fps: %.03f / %d"):format(fps, maxfps))
        else
            print(("fps: %.03f"):format(fps))
        end
    end
    function frame_control()
        local time = gettime()
        clean(time - MaxTimeCachedFrame)
        frame_last = frame_last + 1
        frames[frame_last] = time
        calc_fps()
        --print_fps()
        if maxfps and fps > maxfps then
            local waittime = math.ceil(100/maxfps - (time - lasttime))
            --ltask.sleep(waittime)
            exclusive.sleep(waittime*10)
            lasttime = gettime()
        else
            lasttime = time
        end
    end
end

function S.maxfps(v)
    if not v or v >= 10 then
        maxfps = v
    end
    return maxfps
end

ltask.fork(function()
    while true do
        ltask.sleep(0)
        if encoder_num > 0 and encoder_cur == encoder_num then
            encoder_frame = encoder_frame + 1
            encoder_cur = 0
            local f = bgfx.frame()
            if pause_token then
                ltask.wakeup(pause_token)
                continue_token = {}
                ltask.wait(continue_token)
                continue_token = nil
            end
            wakeup_frame(f)
            frame_control()
        else
            exclusive.sleep(1)
        end
    end
end)

for _, name in ipairs(APIS) do
    if not S[name] then
        S[name] = bgfx[name]
    end
end

return S
