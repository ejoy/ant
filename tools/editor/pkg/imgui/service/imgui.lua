local initargs = ...

local ltask     = require "ltask"
local bgfx      = require "bgfx"
local window    = require "window"
local assetmgr  = import_package "ant.asset"
local rhwi      = import_package "ant.hwi"
local ecs       = import_package "ant.ecs"
local inputmgr  = import_package "ant.inputmgr"

import_package "ant.hwi".init_bgfx()

local world

local WindowMessage = {}
local WindowQueue = {}
local WindowQuit
local WindowToken = {}

ltask.fork(function ()
    while not WindowQuit do
        while true do
            local m = table.remove(WindowQueue, 1)
            if not m then
                break
            end
            world:dispatch_message(m)
        end
        ltask.wait(WindowToken)
    end
end)

local function WindowDispatch()
    if window.peekmessage() then
        if #WindowMessage ~= 0 then
            local wakeup = #WindowQueue == 0
            inputmgr:filter_imgui(WindowMessage, WindowQueue)
            if wakeup then
                ltask.wakeup(WindowToken)
            end
        end
        world:dispatch_message { type = "update" }
        return true
    end
end

ltask.fork(function ()
    local nwh = window.init(WindowMessage, ("%dx%d"):format(initargs.w, initargs.h))
    rhwi.init {
        nwh = nwh,
        w = 1920,
        h = 1080,
    }
    bgfx.encoder_create "world"
    bgfx.encoder_init()
    assetmgr.init()
    bgfx.encoder_begin()

    world = ecs.new_world {
        scene = {
            viewrect = {x = 0, y = 0, w = 1920, h = 1080},
            resolution = {w = 1920, h = 1080},
            scene_ratio = 1,
        },
        device_size = {x=0, y=0, w=1920, h=1080},
        ecs = initargs.ecs,
    }
    WindowDispatch()
    world:pipeline_init()
    while WindowDispatch() do
        world:pipeline_update()
        bgfx.encoder_end()
        rhwi.frame()
        bgfx.encoder_begin()
        ltask.sleep(0)
    end
    WindowQuit = true
    world:pipeline_exit()
    bgfx.encoder_end()
    bgfx.encoder_destroy()
    rhwi.shutdown()
    ltask.multi_wakeup "quit"
    print "exit"
end)

local S = {}

function S.wait()
    ltask.multi_wait "quit"
end

--TODO
function S.msg()
end

return S
