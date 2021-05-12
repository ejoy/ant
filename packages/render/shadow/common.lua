local common = {}; common.__index = common

local hwi 		= import_package "ant.hwi"
local math3d    = require "math3d"

local function calc_bias_matrix()
	-- topleft origin and homogeneous depth matrix
	local m = {
		0.5, 0.0, 0.0, 0.0,
		0.0, -0.5, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		0.5, 0.5, 0.0, 1.0,
	}

	local caps = hwi.get_caps()
	if caps.originBottomLeft then
		m[6] = -m[6]
	end
	
	if caps.homogeneousDepth then
		m[11], m[15] = 0.5, 0.5
	end

	return math3d.ref(math3d.matrix(m))
end

common.sm_bias_matrix = calc_bias_matrix()

return common