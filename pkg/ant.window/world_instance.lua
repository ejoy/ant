local ltask    = require "ltask"
local bgfx     = require "bgfx"
local platform = require "bee.platform"
local assetmgr = import_package "ant.asset"
local audio    = import_package "ant.audio"
local new_world = import_package "ant.world".new_world
local rhwi     = import_package "ant.hwi"

local window
if platform.os ~= "ios" then
    window = require "window"
end

rhwi.init_bgfx()

local ServiceRmlUi
ltask.fork(function ()
    ServiceRmlUi = ltask.uniqueservice("ant.rmlui|rmlui", ltask.self())
end)

local world
local WillReboot
local initargs

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

local function render(nwh, context, width, height, args, initialized)
    local config = {
        ecs = args,
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
    world = new_world(config)
    world:dispatch_message {
        type = "set_viewport",
        viewport = {
            x = 0,
            y = 0,
            w = config.width,
            h = config.height,
        },
    }
    world:dispatch_message { type = "update" }
    world:pipeline_init()
    bgfx.encoder_end()

    ltask.wakeup(initialized)
    initialized = nil

    while true do
        if platform.os ~= "ios" then
            window.peek_message()
            if #WindowQueue > 0 then
                ltask.wakeup(WindowToken)
            end
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
        bgfx.encoder_frame()
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
    ltask.fork(render, m.nwh, m.context, m.w, m.h, initargs, initialized)
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
            local msg = table.remove(WindowQueue, 1)
            if not msg then
                break
            end
            local f = WindowEvent[msg.type]
            if f then
                f(msg)
            elseif not world:dispatch_imgui(msg) then
                world:dispatch_message(msg)
            end
        end
        ltask.wait(WindowToken)
    end
end)

local m = {}

function m.init(args)
    initargs = args
    if platform.os ~= "ios" then
        window.init(WindowQueue, initargs.window_size)
    end
end

function m.reboot(args)
    WillReboot = args
end

local function table_append(t, a)
    table.move(a, 1, #a, #t+1, t)
end

function m.message(messages)
    local wakeup = #WindowQueue == 0
    table_append(WindowQueue, messages)
    if wakeup then
        ltask.wakeup(WindowToken)
    end
end

function m.wait()
    ltask.multi_wait "quit"
end

return m
