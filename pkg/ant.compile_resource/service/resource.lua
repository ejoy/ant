local ltask   = require "ltask"
local bgfx    = require "bgfx"
local cr      = import_package "ant.compile_resource"
local texture = require "thread.texture"
local shader  = require "thread.shader"
import_package "ant.render".init_bgfx()

bgfx.init()
cr.init()

local S = {}

for k, v in pairs(texture.S) do
    S[k] = v
end
for k, v in pairs(shader.S) do
    S[k] = v
end

function S.compile(path)
    return cr.compile(path):string()
end

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
