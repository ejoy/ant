local lfont = require "font"
local bgfx = require "bgfx"

local m = {}

local TextureHandle, TextureW, TextureH

function m.init()
    local fontinit = require "font.init"
    if __ANT_RUNTIME__ then
        lfont(fontinit [[dofile "/pkg/ant.font/manager.lua"]])
    else
        lfont(fontinit (([[
            package.cpath = %q
            package.path = "/pkg/ant.font/?.lua"
            require "vfs"
            dofile "/pkg/ant.font/manager.lua"
        ]]):format(package.cpath)))
    end
    TextureW = lfont.fonttexture_size
    TextureH = lfont.fonttexture_size
    TextureHandle = bgfx.create_texture2d(TextureW, TextureH, false, 1, "A8")
end

function m.handle()
    return lfont.font_manager
end

function m.texture()
    return TextureHandle, TextureW, TextureH
end

return m
