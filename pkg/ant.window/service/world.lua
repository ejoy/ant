local initargs = ...

local ltask    = require "ltask"
local bgfx     = require "bgfx"
local assetmgr = import_package "ant.asset"
local audio    = import_package "ant.audio"
local ecs      = import_package "ant.ecs"
local rhwi     = import_package "ant.hwi"
local inputmgr = import_package "ant.inputmgr"

import_package "ant.hwi".init_bgfx()

local ServiceRmlUi
ltask.fork(function ()
    ServiceRmlUi = ltask.uniqueservice("ant.rmlui|rmlui", ltask.self())
end)

local world
local WillReboot

local WindowQueue = {}
local WindowQuit
local WindowToken = {}
local WindowEvent = {}

local function WindowPushMessage(msgs)
    local wakeup = #WindowQueue == 0
    inputmgr:filter_imgui(msgs, WindowQueue)
    if wakeup then
        ltask.wakeup(WindowToken)
    end
end

local function WindowDispatchMessage()
    world:dispatch_message { type = "update" }
    return true
end

local function reboot(initargs)
    local config = world.args
    local enable_mouse = config.ecs.enable_mouse
    config.REBOOT = true
    config.ecs = initargs
    config.ecs.enable_mouse = enable_mouse
    world:pipeline_exit()
    world = ecs.new_world(config)
    world:pipeline_init()
end

local function render(nwh, context, width, height, initialized)
    local config = {
        ecs = initargs,
        nwh = nwh,
        context = context,
        width = width,
        height = height,
    }
    rhwi.init {
        nwh     = config.nwh,
        context = config.context,
        w       = config.width,
        h       = config.height,
    }
    rhwi.set_profie(false)
    bgfx.encoder_create "world"
    bgfx.encoder_init()
    assetmgr.init()
    bgfx.encoder_begin()
    world = ecs.new_world(config)
    world:dispatch_message {
        type = "set_viewport",
        viewport = {
            x = 0,
            y = 0,
            w = config.width,
            h = config.height,
        },
    }
    WindowDispatchMessage()
    world:pipeline_init()
    bgfx.encoder_end()

    ltask.wakeup(initialized)
    initialized = nil

    while WindowDispatchMessage() do
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
        rhwi.frame()
        ltask.sleep(0)
    end
    if ServiceRmlUi then
        ltask.send(ServiceRmlUi, "shutdown")
        ServiceRmlUi = nil
    end
    world:pipeline_exit()
    world = nil
    bgfx.encoder_destroy()
    rhwi.shutdown()
    ltask.wakeup(WindowQuit)
end

function WindowEvent.init(m)
    local initialized = {}
    ltask.fork(render, m.nwh, m.context, m.w, m.h, initialized)
    ltask.wait(initialized)
end

function WindowEvent.recreate(m)
    bgfx.set_platform_data {
        nwh = m.nwh
    }
    world:dispatch_message {
        type = "size",
        w = m.w,
        h = m.h,
    }
end

function WindowEvent.suspend(m)
    bgfx.event_suspend(m.what)
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
            local m = table.remove(WindowQueue, 1)
            if not m then
                break
            end
            local f = WindowEvent[m.type]
            if f then
                f(m)
            else
                world:dispatch_message(m)
            end
        end
        ltask.wait(WindowToken)
    end
end)

local S = ltask.dispatch {}

function S.msg(messages)
    WindowPushMessage(messages)
end

function S.reboot(initargs)
    WillReboot = initargs
end

function S.wait()
    ltask.multi_wait "quit"
end
