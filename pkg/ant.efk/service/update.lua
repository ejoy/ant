local context, updatefunc = ...

local ltask = require "ltask"
local bgfx = require "bgfx"
local hwi = import_package "ant.hwi"
hwi.init_bgfx()
bgfx.init()
bgfx.encoder_create "efk"

local EventUpdate <const> = {}
local quit

ltask.fork(function ()
    while not quit do
        ltask.wait(EventUpdate)
        updatefunc(context)
        bgfx.encoder_frame()
    end
end)

local S = {}

function S.update()
    ltask.wakeup(EventUpdate)
end

function S.quit()
    quit = {}
    bgfx.encoder_destroy()
    bgfx.shutdown()
    ltask.quit()
end

return S
