local constant = {}; constant.__index = constant

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
constant.ZERO   = {0, 0, 0, 0}
constant.ZERO_PT= {0, 0, 0, 1}
constant.X_AXIS = {1, 0, 0, 0}
constant.Y_AXIS = {0, 1, 0, 0}
constant.Z_AXIS = {0, 0, 1, 0}
constant.W_AXIS = {0, 0, 0, 1}

return constant