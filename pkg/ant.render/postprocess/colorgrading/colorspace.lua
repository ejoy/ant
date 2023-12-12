local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc, mu = mathpkg.constant, mathpkg.util

local function cv3(x, y, z)
    return math3d.constant("v4", {x, y, z, 0.0})
end

local cs = {
    ILLUMINANT_D65_xyY      = cv3(0.31271, 0.32902, 1.0),
    XYZ_to_CIECAT16         = mu.from_cmat3(
                                0.401288, -0.250268, -0.002079,
                                0.650173,  1.204414,  0.048952,
                                -0.051461,  0.045854,  0.953127),
    XYZ_to_Rec2020          = mu.from_cmat3(
                                1.7166634, -0.6666738,  0.0176425,
                                -0.3556733,  1.6164557, -0.0427770,
                                -0.2533681,  0.0157683,  0.9422433),
    
    CIECAT16_to_XYZ         = mu.from_cmat3(
                                1.862068,  0.387527, -0.015841,
                                -1.011255,  0.621447, -0.034123,
                                0.149187, -0.008974,  1.049964);
    ILLUMINANT_D65_LMS_CAT16= cv3(0.975533, 1.016483, 1.084837),
    LUMINANCE_Rec2020       = cv3(0.2627002, 0.6779981, 0.0593017),
    Rec2020_to_XYZ          = mu.from_cmat3(
                                0.6369530,  0.2626983,  0.0000000,
                                0.1446169,  0.6780088,  0.0280731,
                                0.1688558,  0.0592929,  1.0608272),
    sRGB_to_XYZ             = mu.from_cmat3(
                                0.4124560,  0.2126730,  0.0193339,
                                0.3575760,  0.7151520,  0.1191920,
                                0.1804380,  0.0721750,  0.9503040),
    XYZ_to_sRGB             = mu.from_cmat3(
                                3.2404542, -0.9692660,  0.0556434,
                                -1.5371385,  1.8760108, -0.2040259,
                                -0.4985314,  0.0415560,  1.0572252),
    AP1_to_XYZ              = mu.from_cmat3(
                                0.6624541811,  0.2722287168, -0.0055746495,
                                0.1340042065,  0.6740817658,  0.0040607335,
                                0.1561876870,  0.0536895174,  1.0103391003),
    
    XYZ_to_AP1              = mu.from_cmat3(
                                1.6410233797, -0.6636628587,  0.0117218943,
                                -0.3248032942,  1.6153315917, -0.0082844420,
                                -0.2364246952,  0.0167563477,  0.9883948585),
    AP1_to_AP0              = mu.from_cmat3(
                                0.6954522414,  0.0447945634, -0.0055258826,
                                0.1406786965,  0.8596711185,  0.0040252103,
                                0.1638690622,  0.0955343182,  1.0015006723),
    
    AP0_to_AP1              = mu.from_cmat3(
                                1.4514393161, -0.0765537734,  0.0083161484,
                                -0.2365107469,  1.1762296998, -0.0060324498,
                                -0.2149285693, -0.0996759264,  0.9977163014),
    AP1_to_sRGB             = mu.from_cmat3(
                                1.70505, -0.13026, -0.02400,
                                -0.62179,  1.14080, -0.12897,
                                -0.08326, -0.01055,  1.15297),

    -- RGB to luminance coefficients for ACEScg (AP1), from AP1_to_XYZ
    LUMINANCE_AP1           = cv3(0.272229, 0.674082, 0.0536895),
    
    -- RGB to luminance coefficients for Rec.709, from sRGB_to_XYZ
    LUMINANCE_Rec709        = cv3(0.2126730, 0.7151520, 0.0721750),
    
    -- RGB to luminance coefficients for Rec.709 with HK-like weighting
    LUMINANCE_HK_Rec709     = cv3(0.13913043, 0.73043478, 0.13043478),
}

cs.LMS_CAT16_to_Rec2020     = math3d.constant("mat",math3d.mul(cs.XYZ_to_Rec2020, cs.CIECAT16_to_XYZ))
cs.Rec2020_to_LMS_CAT16     = math3d.constant("mat",math3d.mul(cs.XYZ_to_CIECAT16, cs.Rec2020_to_XYZ))

cs.sRGB_to_Rec2020          = math3d.constant("mat", math3d.mul(cs.XYZ_to_Rec2020, cs.sRGB_to_XYZ))
cs.Rec2020_to_sRGB          = math3d.constant("mat", math3d.mul(cs.XYZ_to_sRGB, cs.Rec2020_to_XYZ))

cs.Rec2020_to_AP0           = math3d.constant("mat", math3d.mul(math3d.mul(cs.AP1_to_AP0, cs.XYZ_to_AP1), cs.Rec2020_to_XYZ))
cs.AP1_to_Rec2020           = math3d.constant("mat", math3d.mul(cs.XYZ_to_Rec2020, cs.AP1_to_XYZ))

function cs.EOTF_sRGB(x)
    local a <const> = 0.055
    local a1<const> = 1.055
    local b <const> = 1.0 / 12.92
    local p <const> = 2.4
    local function T(v)
        return v <= 0.04045 and v * b or (((v + a) / a1)^ p)
    end
    local xx, yy, zz = math3d.index(x, 1, 2, 3)
    return math3d.vector(T(xx), T(yy), T(zz))
end

function cs.OETF_sRGB(x)
    local a <const> = 0.055
    local a1<const> = 1.055
    local b <const> = 12.92
    local p <const> = 1 / 2.4
    local xx, yy, zz = math3d.index(x, 1, 2, 3)

    local function T(v)
        return v <= 0.0031308 and (v * b) or (a1 * (v ^ p) - a)
    end
    return math3d.vector(T(xx), T(yy), T(zz))
end

function cs.OETF_linear(x) return x end

function cs.xyY_to_XYZ(xyY)
    local x, y, Y = math3d.index(xyY, 1, 2, 3)
    local a = Y / math.max(y, 1e-5);
    return math3d.vector(x * a, Y, (1.0 - x - y) * a)
end

function cs.XYZ_to_xyY(XYZ)
    local x, y, z = math3d.index(XYZ, 1, 2, 3)
    local l = math.max(x+y+z, 1e-5)
    return math3d.vector(x / l, y / l, y)
end

function cs.LogC_to_linear(v)
    local ia<const> = 1.0 / 5.555556
    local b <const> = 0.047996
    local ic<const> = 1.0 / 0.244161
    local d <const> = 0.386036

    --((10.0 ^ (((v - d) * ic))) - b) * ia
    local p = math3d.mul(math3d.sub(v, d), ic)
    return math3d.mul(math3d.sub(math3d.pow(p, 10), b), ia)
end

-- Encodes a linear value in LogC using the Alexa LogC EI 1000 curve
function cs.linear_to_LogC(v)
    local a<const> = 5.555556
    local b<const> = 0.047996
    local c<const> = 0.244161
    local d<const> = 0.386036

    --c * log10(a * x + b) + d;
    math3d.muladd(c, math3d.log(math3d.muladd(a, v, b)), d)
end

return cs