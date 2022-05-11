local math3d		= require "math3d"
local bgfx			= require "bgfx"
local rmat			= require "render.material"
local CMATOBJ		= rmat.cobject {
    bgfx = assert(bgfx.CINTERFACE) ,
    math3d = assert(math3d.CINTERFACE),
    encoder = assert(bgfx.encoder_get()),
}

return CMATOBJ