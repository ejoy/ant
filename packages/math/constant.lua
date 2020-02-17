local constant = {}; constant.__index = constant
local ms = require "stack"
-- matrix
constant.mat_identity = {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
}

-- color
constant.RED    = {1, 0, 0, 1}
constant.GREEN  = {0, 1, 0, 1}
constant.BLUE   = {0, 0, 1, 1}
constant.BLACK  = {0, 0, 0, 1}
constant.WHITE  = {1, 1, 1, 1}
constant.YELLOW = {1, 1, 0, 1}
constant.GRAY_HALF = {0.5, 0.5, 0.5, 1}
constant.GRAY   = {0.8, 0.8, 0.8, 1}

-- value
constant.T_ZERO   = {0, 0, 0, 0}
constant.T_ZERO_PT= {0, 0, 0, 1}

constant.T_XAXIS = {1, 0, 0, 0}
constant.T_NXAXIS = {-1, 0, 0, 0}

constant.T_YAXIS = {0, 1, 0, 0}
constant.T_NYAXIS = {0, -1, 0, 0}

constant.T_ZAXIS = {0, 0, 1, 0}
constant.T_NZAXIS = {0, 0, -1, 0}

constant.W_AXIS = {0, 0, 0, 1}

constant.ZERO    = ms:ref "vector"(constant.T_ZERO)
constant.ZERO_PT = ms:ref "vector"(constant.T_ZERO_PT)

constant.XAXIS   = ms:ref "vector"(constant.T_XAXIS)
constant.NXAXIS  = ms:ref "vector"(constant.T_NXAXIS)

constant.YAXIS   = ms:ref "vector"(constant.T_YAXIS)
constant.NYAXIS  = ms:ref "vector"(constant.T_NYAXIS)

constant.ZAXIS   = ms:ref "vector"(constant.T_ZAXIS)
constant.NZAXIS  = ms:ref "vector"(constant.T_NZAXIS)

constant.IDENTITY_MAT = ms:ref "matrix"(constant.mat_identity)

constant.IDENTITY_QUAT = ms:ref "quaternion"({type='q', 0, 0, 0, 1})

return constant