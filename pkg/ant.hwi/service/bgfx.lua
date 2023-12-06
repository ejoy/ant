local ltask         = require "ltask"
local exclusive     = require "ltask.exclusive"
local bgfx          = require "bgfx"
local platform      = require "bee.platform"
local fontmanager

local initialized = false

local CALL = {
    "init",
    "set_platform_data",
    "frame",
    "shutdown",
    "request_screenshot",
    "reset",
    "set_debug",
    "get_log",

    "encoder_create",
    "encoder_destroy",
    "encoder_frame",
    "maxfps",
    "fontmanager",
    "fontimport",
    "show_profile",
    "event_suspend",

    "fetch_world_camera",
    "update_world_camera",
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
local profile_printtext = {n=0}

local bgfx_stat = {}
local views = {}

local PROFILE_SHOW_STATE = {
    fps = true,
    time = true,
    system = true,
    view = true,
    encoder = true,
}

local function stats_views()
    local stats = bgfx.get_stats("vc", bgfx_stat)
    local mark = {}
    for i = 1, #stats.view do
        local s = stats.view[i]
        local name = s.name
        local v = views[name]
        if mark[s.name] then
            v.cpu = v.cpu + s.cpu
        else
            mark[name] = true
            if v then
                v.gpu = v.gpu + s.gpu
                v.cpu = v.cpu + s.cpu
            else
                v = {
                    name = name,
                    gpu = s.gpu,
                    cpu = s.cpu,
                }
                views[#views+1] = v
                views[name] = v
            end
        end
    end
end

local function profile_print()
    if PROFILE_SHOW_STATE.view then
        stats_views()
    end

    if not PROFILE_SHOW_STATE.encoder then
        return
    end

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

        local function format_text(name, value)
            return ("  %s%s%s"):format(name, (" "):rep(MaxName-#name), value)
        end

        profile_printtext.n = 0
        local function add_text(t)
            profile_printtext.n = profile_printtext.n + 1
            profile_printtext[profile_printtext.n] = t
        end

        add_text "--- encoder"
        for i = 1, #r do
            local who, time = r[i][1], r[i][2]
            local m = time / MaxFrame * 1000
            local name = ("%s(%d)"):format(profile_label[who], who)
            add_text(format_text(name, (" | %.02fms   "):format(m)))
            profile[who] = 0
        end

        table.sort(views, function (a, b) return a.gpu > b.gpu end)
        add_text "--- view"
        for i = 1, 5 do
            local view = views[i]
            if view then
                local name = view.name
                add_text(format_text(name, (" | gpu %.02fms cpu %.02fms "):format(view.gpu / MaxFrame, view.cpu / MaxFrame)))
            else
                break
            end
        end
        views = {}

        add_text "--- submit"
        add_text(format_text("draw|blit|compute|gpuLatency", (" | %d %d %d %dms"):format(bgfx_stat.numDraw, bgfx_stat.numBlit, bgfx_stat.numCompute, bgfx_stat.maxGpuLatency)))
        local rs = require "render.stat"
        local ss = rs.submit_stat()
        if next(ss) then
            add_text(format_text("simple|hitch|efk", (" | %d %d %d"):format(ss.simple_submit, ss.hitch_submit, ss.efk_hitch_submit)))
            add_text(format_text("hitch_count", (" | %d"):format(ss.hitch_count)))
        end
    end
    for i = 1, profile_printtext.n do
        S.dbg_text_print(0, 2+MaxText+i, 0x02, profile_printtext[i])
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

function S.event_suspend(what)
    if what == "will_suspend" then
        S.pause()
    elseif what == "did_resume" then
        S.continue()
    end
end

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
        return
    end
    ltask.wakeup(continue_token)
end

local WORLD_CAMERA_STATE = {
    viewmat = nil,
    projmat = nil,
    deltatime = 0,
    which_consumer  = nil,
    clear = function (self)
        self.viewmat = nil
        self.projmat = nil
        self.deltatime = 0
    end,
    update = function(self, viewmat, projmat, deltatime)
        assert(not self:already_update())
        self.viewmat = viewmat
        self.projmat = projmat
        self.deltatime = deltatime
        self:check_wakeup()
    end,
    already_update = function(self)
        return nil ~= self.viewmat
    end,
    check_wakeup = function (self)
        if nil ~= self.which_consumer then
            ltask.wakeup(self.which_consumer)
        end
    end,
    check_and_wait = function (self)
        if not self:already_update() then
            self.which_consumer = coroutine.running()
            ltask.wait(self.which_consumer)
            self.which_consumer = nil
        end
    end,
}

function S.fetch_world_camera()
    WORLD_CAMERA_STATE:check_and_wait()
    return WORLD_CAMERA_STATE.viewmat, WORLD_CAMERA_STATE.projmat, WORLD_CAMERA_STATE.deltatime
end

function S.update_world_camera(...)
    WORLD_CAMERA_STATE:update(...)
end

function S.frame()
    if not continue_token then
        error "Can only be used in pause."
    end
    return bgfx.frame()
end

function S.show_profile(what, show)
    if show == nil then
        show = false
    end

    for ww in what:gmatch "%w+" do
        if not PROFILE_SHOW_STATE[ww] then
            log.warn(("Invalid profile name: %s, fps|time|encoder is valid"):format(ww))
        end

        PROFILE_SHOW_STATE[ww] = show
    end
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
        if not PROFILE_SHOW_STATE.fps then
            return
        end
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
        if not PROFILE_SHOW_STATE.time then
            return
        end
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
    --TODO: editor does not have "ant.window|window"
    if platform.os == "ios" then
        local ServiceWindow = ltask.queryservice "ant.window|window"
        ltask.call(ServiceWindow, "maxfps", maxfps)
    end
    return maxfps
end

function S.dbg_text_print(x, y, ...)
    return bgfx.dbg_text_print(x + 16, y + 1, ...)
end

function S.fontmanager()
    return fontmanager.instance()
end

function S.fontimport(path)
    return fontmanager.import(path)
end

local viewidmgr = require "viewid_mgr"

local function mainloop()
    while initialized do
        if encoder_num > 0 and encoder_cur == encoder_num then
            encoder_frame = encoder_frame + 1
            encoder_cur = 0
            viewidmgr.check_remapping()
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
            WORLD_CAMERA_STATE:clear()
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

local function init_args(args)
    local maxwh = math.max(args.width, args.height)
    if maxwh > 1920 then
        args.debugTextScale = 2
    else
        args.debugTextScale = 1
    end
end

local function init_resource()
    local vfs = require "vfs"
    local caps = bgfx.get_caps()
    local renderer = caps.rendererType:lower()
    vfs.resource_setting(("%s-%s"):format(platform.os, renderer))
end

function S.init(args)
    if init_token == nil then
    elseif args == nil then
        ltask.wait(init_token)
    else
        init_args(args)
        bgfx.init(args)
        init_resource()
        fontmanager = require "font.fontmanager"
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
        fontmanager.shutdown()
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

S.viewid_get        = viewidmgr.get
S.viewid_generate   = viewidmgr.generate
S.viewid_name       = viewidmgr.name
return S
