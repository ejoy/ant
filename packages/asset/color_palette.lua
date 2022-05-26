local CMATOBJ   = require "cmatobj"
local rmat      = require "render.material"

local math3d    = require "math3d"

return {
	default = rmat.color_palette(CMATOBJ,{
		math3d.vector(0.0, 0.0, 0.0, 1.0),
		math3d.vector(1.0, 1.0, 1.0, 1.0),
		math3d.vector(1.0, 0.0, 0.0, 1.0),
		math3d.vector(1.0, 1.0, 0.0, 1.0),
		math3d.vector(1.0, 0.0, 1.0, 1.0),
		math3d.vector(0.0, 1.0, 1.0, 1.0),
		math3d.vector(0.0, 0.0, 1.0, 1.0),
	}),
}