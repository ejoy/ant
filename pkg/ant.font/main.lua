local lfont = require "font"
local bgfx = require "bgfx"
local fontvm = require "font.vm"
--local layout = require "layout"
local m = {}

local TextureHandle, TextureW, TextureH

function m.init()
    --local layoutinit = require "layout.init"
    if __ANT_RUNTIME__ then
        lfont(fontvm.init [[dofile "/pkg/ant.font/manager.lua"]])
        --layout(layoutinit [[dofile "/pkg/ant.font/manager.lua"]])
    else
        lfont(fontvm.init (([[
            package.cpath = %q
            package.path = "/pkg/ant.font/?.lua"
            local dbg = assert(loadfile '/engine/debugger.lua')()
            if dbg then
                dbg:event("setThreadName", "Font thread")
                dbg:event "wait"
            end
            require "vfs"
            dofile "/pkg/ant.font/manager.lua"
        ]]):format(package.cpath)))
    end
    TextureW = lfont.fonttexture_size
    TextureH = lfont.fonttexture_size
    TextureHandle = bgfx.create_texture2d(TextureW, TextureH, false, 1, "A8")
end

function m.close()
    fontvm.close()
end

function m.handle()
    return lfont.font_manager
end

function m.import(filename)
    return lfont.import(filename:localpath():string())
end

function m.texture()
    return TextureHandle, TextureW, TextureH
end

return m
