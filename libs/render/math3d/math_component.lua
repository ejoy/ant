local ecs = ...
local bgfx = require "bgfx"
--{@
local math3d = require "math3d"
local math3d_comp = ecs.component "math_stack"

function math3d_comp.new()
	local initMath3dDebug = require 'debugger.math3d'
	local caps = bgfx.get_caps();
	local ms = math3d.new(caps.homogeneousDepth)
	return initMath3dDebug(ms)
end

function math3d_comp:constant(id, value)
	return self(id,value,"MR")
end
--@}

