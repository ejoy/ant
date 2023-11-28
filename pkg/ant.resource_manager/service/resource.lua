local ltask   = require "ltask"
import_package "ant.hwi".init_bgfx()

local bgfx = require "bgfx"
bgfx.init()

local texture = require "thread.texture"
require "thread.material"

local S = require "thread.main"

local quit

ltask.fork(function ()
    bgfx.encoder_create "resource"
    while not quit do
        texture.update()
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end)

function S.quit()
    quit = {}
    ltask.wait(quit)
    bgfx.shutdown()
    ltask.quit()
end

return S
