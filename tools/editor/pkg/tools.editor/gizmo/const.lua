local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local math3d = require "math3d"
local m = {
    SELECT                  = 0,
    MOVE                    = 1,
    ROTATE                  = 2,
    SCALE                   = 3,
    DIR_X                   = mc.T_XAXIS,
    DIR_Y                   = mc.T_YAXIS,
    DIR_Z                   = mc.T_ZAXIS,
    COLOR                   = {
        X                 = {1, 0, 0, 1},
        Y                 = {0, 1, 0, 1},
        Z                 = {0, 0, 1, 1},
        X_ALPHA           = {1, 0, 0, 0.5},
        Y_ALPHA           = {0, 1, 0, 0.5},
        Z_ALPHA           = {0, 0, 1, 0.5},
        GRAY              = {0.8, 0.8, 0.8, 1},
        GRAY_ALPHA        = math3d.ref(math3d.vector(1, 1, 1, 0.5)),
        HIGHLIGHT         = math3d.ref(math3d.vector(1, 1, 0, 1)),
        HIGHLIGHT_ALPHA   = math3d.ref(math3d.vector(1, 1, 0, 0.5)),
    },
    RIGHT_TOP               = 0,
    RIGHT_BOTTOM            = 1,
    LEFT_BOTTOM             = 2,
    LEFT_TOP                = 3,
    AXIS_CUBE_SCALE         = 0.025,
    AXIS_LEN                = 0.2,
    UNIFORM_ROT_AXIS_LEN    = 0.25,
    MOVE_PLANE_SCALE        = 0.08,
    MOVE_PLANE_OFFSET       = 0.04,
    MOVE_PLANE_HIT_RADIUS   = 0.22,
    ROTATE_SLICES           = 72,
    ROTATE_HIT_RADIUS       = 0.02,
    MOVE_HIT_RADIUS_PIXEL   = 10
}

return m