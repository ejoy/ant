local bgfx = require "bgfx"

local math3d = require "math3d"
local initMath3dDebug = require 'debugger.math3d'

local caps = bgfx.get_caps();
local ms = math3d.new(caps.homogeneousDepth)
return initMath3dDebug(ms)