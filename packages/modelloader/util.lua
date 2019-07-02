local util = {}; util.__index = util

local gltf = import_package "ant.glTF"
local gltfutil = gltf.util

local bgfx = require "bgfx"
local declmgr = import_package "ant.render".declmgr
local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mathbaselib = require "math3d.baselib"

return util