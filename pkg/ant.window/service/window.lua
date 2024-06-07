local ltask     = require "ltask"
local bgfx      = require "bgfx"
local window    = require "window"
local assetmgr  = import_package "ant.asset"
local audio     = import_package "ant.audio"
local new_world = import_package "ant.world".new_world
local rhwi      = import_package "ant.hwi"

rhwi.init_bgfx()

local world
local WillReboot
local initargs = ...

local WindowQueue = {}
local WindowQuit
local WindowToken = {}
local WindowEvent = {}

local function reboot(args)
    local config = world.args
    config.REBOOT = true
    config.ecs = args
    world:pipeline_exit()
    world = new_world(config)
    world:pipeline_init()
end

local function render(init, args, initialized)
    rhwi.init {
        nwh     = init.nwh,
        ndt     = init.ndt,
        context = init.context,
        width   = init.w,
        height  = init.h,
    }
    rhwi.set_native_window(init.window)
    rhwi.set_profie(false)
    bgfx.encoder_create "world"
    bgfx.encoder_init()
    assetmgr.init()
    bgfx.encoder_begin()
    world = new_world {
        ecs    = args,
        width  = init.w,
        height = init.h,
    }
    world:dispatch_message {
        type = "window_init",
        size = {
            w = init.w,
            h = init.h,
        },
    }
    world:dispatch_message { type = "update" }
    world:pipeline_init()
    bgfx.encoder_end()

    ltask.wakeup(initialized)
    initialized = nil

    while true do
        window.peek_message()
        if #WindowQueue > 0 then
            ltask.wakeup(WindowToken)
        end
        world:dispatch_message { type = "update" }
        if WindowQuit then
            break
        end
        bgfx.encoder_begin()
        if WillReboot then
            reboot(WillReboot)
            WillReboot = nil
        end
        world:pipeline_update()
        bgfx.encoder_end()
        audio.frame()
        world._frametime = bgfx.encoder_frame()
    end
    world:pipeline_exit()
    world = nil
    bgfx.encoder_destroy()
    bgfx.shutdown()
    ltask.wakeup(WindowQuit)
end

function WindowEvent.init(m)
    local initialized = {}
    ltask.fork(render, m, initargs, initialized)
    ltask.wait(initialized)
end

function WindowEvent.recreate(m)
    bgfx.set_platform_data {
        nwh = m.nwh,
        ndt = m.ndt,
        context = m.context,
    }
    world:dispatch_message {
        type = "size",
        w = m.w,
        h = m.h,
    }
end

local PAUSE
function WindowEvent.suspend(m)
    if m.what == "will_suspend" then
        bgfx.pause()
        PAUSE = true
        ltask.fork(function ()
            local thread = require "bee.thread"
            while PAUSE do
                window.peek_message()
                if #WindowQueue > 0 then
                    ltask.wakeup(WindowToken)
                else
                    thread.sleep(10)
                end
                ltask.sleep(0)
            end
        end)
    elseif m.what == "did_resume" then
        world:dispatch_message(m)
        bgfx.continue()
        PAUSE = nil
    end
end

function WindowEvent.exit()
    WindowQuit = {}
    ltask.wait(WindowQuit)
    print "exit"
    ltask.multi_wakeup "quit"
end

ltask.fork(function ()
    while not WindowQuit do
        while true do
            local msg = table.remove(WindowQueue, 1)
            if not msg then
                break
            end
            local f = WindowEvent[msg.type]
            if f then
                f(msg)
            else
                if not world:dispatch_imgui(msg) then
                    world:dispatch_message(msg)
                end
            end
        end
        ltask.wait(WindowToken)
    end
end)

local function table_append(t, a)
    table.move(a, 1, #a, #t+1, t)
end

local S = {}

function S.reboot(args)
    WillReboot = args
end

function S.wait()
    ltask.multi_wait "quit"
end

function S.msg(messages)
    local wakeup = #WindowQueue == 0
    table_append(WindowQueue, messages)
    if wakeup then
        ltask.wakeup(WindowToken)
    end
end

function S.set_cursor(cursor)
    window.set_cursor(cursor)
end

function S.show_cursor(show)
    window.show_cursor(show)
end

function S.set_title(title)
    window.set_title(title)
end

function S.set_maxfps(fps)
    window.set_maxfps(fps)
end

function S.set_fullscreen(fullscreen)
    window.set_fullscreen(fullscreen)
end

function S.get_cmd()
	return initargs.cmd
end

if initargs.log then
	-- set log level : 'trace','debug', 'info', 'warn', 'error', 'fatal'
	log.level = initargs.log
end

window.init(WindowQueue, initargs.window_size)

return S
