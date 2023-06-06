local lfont = require "font"
local bgfx = require "bgfx"
local m = {}

local TextureHandle, TextureW, TextureH

function m.init()
    local fontmanager = bgfx.fontmanager()
    lfont(fontmanager)
    TextureW = lfont.fonttexture_size
    TextureH = lfont.fonttexture_size
    TextureHandle = bgfx.create_texture2d(TextureW, TextureH, false, 1, "A8")
    return fontmanager
end

function m.import(filename)
    return lfont.import(filename:localpath():string())
end

function m.texture()
    return TextureHandle, TextureW, TextureH
end

return m
