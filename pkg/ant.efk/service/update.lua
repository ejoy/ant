local ltask = require "ltask"

local ServiceBgfxEvent <const> = ltask.queryservice "ant.hwi|event"
local bgfx = require "bgfx"
local hwi = import_package "ant.hwi"
hwi.init_bgfx()
bgfx.init()
bgfx.encoder_create "efk"

local quit

ltask.fork(function ()
    while not quit do
        local ctx, func = ltask.call(ServiceBgfxEvent, "wait", "efk")
        if ctx then
            func(ctx)
        end
        bgfx.encoder_frame()
    end
end)

local S = {}

function S.quit()
    quit = {}
    bgfx.encoder_destroy()
    bgfx.shutdown()
    ltask.quit()
end

return S
