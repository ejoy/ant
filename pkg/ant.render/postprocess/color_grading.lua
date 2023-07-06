local math3d = require "math3d"
local ILLUMINANT_D65_xyY<const> = math3d.constant(math3d.vector(0.31271, 0.32902, 1.0))

local function from_mat3(
    c11, c12, c13,
    c21, c22, c23,
    c31, c32, c33)
    return math3d.constant(math3d.matrix(
        c11, c12, c13, 0.0,
        c21, c22, c23, 0.0,
        c31, c32, c33, 0.0,
        0.0, 0.0, 0.0, 0.0))
end

local XYZ_to_CIECAT16<const> = from_mat3(
    0.401288, -0.250268, -0.002079,
    0.650173,  1.204414,  0.048952,
   -0.051461,  0.045854,  0.953127)

local XYZ_to_Rec2020<const> = from_mat3(
     1.7166634, -0.6666738,  0.0176425,
    -0.3556733,  1.6164557, -0.0427770,
    -0.2533681,  0.0157683,  0.9422433)

local CIECAT16_to_XYZ<const> = from_mat3(
    1.862068,  0.387527, -0.015841,
   -1.011255,  0.621447, -0.034123,
    0.149187, -0.008974,  1.049964);

local ILLUMINANT_D65_LMS_CAT16<const> = math3d.vector(0.975533, 1.016483, 1.084837)

local LMS_CAT16_to_Rec2020<const> = math3d.constant(math3d.mul(XYZ_to_Rec2020, CIECAT16_to_XYZ))

local function xyY_to_XYZ(xyY)
    local x, y, Y = math3d.index(xyY, 2, 3)
    local a = Y / math.max(y, 1e-5);
    return math3d.vector(x * a, Y, (1.0 - x - y) * a)
end

local function XYZ_to_xyY(XYZ)
    local x, y, z = math3d.index(XYZ)
    local l = math.max(x+y+z, 1e-5)
    return math3d.vector(x / l, y / l, y)
end

-- Returns the y chromaticity coordinate in xyY for an illuminant series D,
-- given its x chromaticity coordinate.
local function chromaticityCoordinateIlluminantD(x)
    -- See http://en.wikipedia.org/wiki/Standard_illuminant#Illuminant_series_D
    return 2.87 * x - 3.0 * x * x - 0.275;
end

--White balance
local function adaptationTransform(temperature, tint)
-- Return the chromatic adaptation coefficients in LMS space for the given
-- temperature/tint offsets. The chromatic adaption is perfomed following
-- the von Kries method, using the CIECAT16 transform.
-- See https://en.wikipedia.org/wiki/Chromatic_adaptation
-- See https://en.wikipedia.org/wiki/CIECAM02#Chromatic_adaptation

    local x = math3d.index(ILLUMINANT_D65_xyY, 1) - temperature * (temperature < 0.0 and 0.0214 or 0.066)
    local y = chromaticityCoordinateIlluminantD(x) + tint * 0.066

    local lms = math3d.transform(XYZ_to_CIECAT16, xyY_to_XYZ(math3d.vector(x, y, 1.0)), 0)

    local m
    do
        local v = math3d.mul(ILLUMINANT_D65_LMS_CAT16, math3d.reciprocal(lms))
        local x, y, z = math3d.index(v, 1, 2, 3)
        m = from_mat3(
            x,   0.0, 0.0,
            0.0, y,   0.0,
            0.0, 0.0, z)
    end

    return math3d.mul(ILLUMINANT_D65_LMS_CAT16, math3d.mul(LMS_CAT16_to_Rec2020, m))
end

local function bake(dim)
    local cfg = {
        adaptationTransform   = adaptationTransform(builder->whiteBalance),
        colorGradingIn        = selectColorGradingTransformIn(builder->toneMapping),
        colorGradingOut       = selectColorGradingTransformOut(builder->toneMapping),
        colorGradingLuminance = selectColorGradingLuminance(builder->toneMapping),
        oetf                  = selectOETF(builder->outputColorSpace),
    }
end

return {
    bake = bake,
}