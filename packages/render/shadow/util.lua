local util = {}; util.__index = util

local mathpkg   = import_package "ant.math"
local ms        = mathpkg.stack

util.shadow_crop_matrix = ms:ref "matrix" {
	0.5, 0.0, 0.0, 0.0,
	0.0, 0.5, 0.0, 0.0,
	0.0, 0.0, 1.0, 0.0,
	0.5, 0.5, 0.0, 1.0,
}

return util