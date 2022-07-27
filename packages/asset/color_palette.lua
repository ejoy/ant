local ecs		= ...
local matobj	= require "matobj"
local math3d    = require "math3d"

return {
	default = matobj.rmat.color_palette{
		math3d.vector(0.0, 0.0, 0.0, 1.0),
		math3d.vector(1.0, 1.0, 1.0, 1.0),
		math3d.vector(1.0, 0.0, 0.0, 1.0),
		math3d.vector(1.0, 1.0, 0.0, 1.0),
		math3d.vector(1.0, 0.0, 1.0, 1.0),
		math3d.vector(0.0, 1.0, 1.0, 1.0),
		math3d.vector(0.0, 0.0, 1.0, 1.0),
	},
}