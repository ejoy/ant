local math3d = require "math3d"

local mathpkg = import_package "ant.math"
local mc, mu = mathpkg.constant, mathpkg.util

local ACES = require "postprocess.aces"

local ILLUMINANT_D65_xyY<const> = math3d.constant(math3d.vector(0.31271, 0.32902, 1.0))

local XYZ_to_CIECAT16<const> = mu.from_cmat3(
    0.401288, -0.250268, -0.002079,
    0.650173,  1.204414,  0.048952,
   -0.051461,  0.045854,  0.953127)

local XYZ_to_Rec2020<const> = mu.from_cmat3(
     1.7166634, -0.6666738,  0.0176425,
    -0.3556733,  1.6164557, -0.0427770,
    -0.2533681,  0.0157683,  0.9422433)

local CIECAT16_to_XYZ<const> = mu.from_cmat3(
    1.862068,  0.387527, -0.015841,
   -1.011255,  0.621447, -0.034123,
    0.149187, -0.008974,  1.049964);

local ILLUMINANT_D65_LMS_CAT16<const> = math3d.constant(math3d.vector(0.975533, 1.016483, 1.084837))

local LMS_CAT16_to_Rec2020<const> = math3d.constant(math3d.mul(XYZ_to_Rec2020, CIECAT16_to_XYZ))

local LUMINANCE_Rec2020<const> = math3d.constant(math3d.vector(0.2627002, 0.6779981, 0.0593017))

local function EOTF_sRGB(x)
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

local Rec2020_to_XYZ<const> = mu.from_cmat3(
    0.6369530,  0.2626983,  0.0000000,
    0.1446169,  0.6780088,  0.0280731,
    0.1688558,  0.0592929,  1.0608272)

local Rec2020_to_LMS_CAT16<const> = math3d.constant(math3d.mul(XYZ_to_CIECAT16, Rec2020_to_XYZ))

local sRGB_to_XYZ<const> = mu.from_cmat3(
    0.4124560,  0.2126730,  0.0193339,
    0.3575760,  0.7151520,  0.1191920,
    0.1804380,  0.0721750,  0.9503040)
local XYZ_to_sRGB<const> = mu.from_cmat3(
    3.2404542, -0.9692660,  0.0556434,
   -1.5371385,  1.8760108, -0.2040259,
   -0.4985314,  0.0415560,  1.0572252)

local sRGB_to_Rec2020<const> = math3d.constant(math3d.mul(XYZ_to_Rec2020, sRGB_to_XYZ))
local Rec2020_to_sRGB<const> = math3d.constant(math3d.mul(XYZ_to_sRGB, Rec2020_to_XYZ))

local function LogC_to_linear(x)
    local ia<const> = 1.0 / 5.555556
    local b <const> = 0.047996
    local ic<const> = 1.0 / 0.244161
    local d <const> = 0.386036
    return (10.0 ^ (((x - d) * ic) - b)) * ia
end

-- Encodes a linear value in LogC using the Alexa LogC EI 1000 curve
local function linear_to_LogC(x)
    local a<const> = 5.555556
    local b<const> = 0.047996
    local c<const> = 0.244161
    local d<const> = 0.386036
    return c * math.log(a * x + b, 10) + d
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
        m = mu.from_mat3(
            x,   0.0, 0.0,
            0.0, y,   0.0,
            0.0, 0.0, z)
    end

    --LMS_CAT16_to_Rec2020 * mat3f{ILLUMINANT_D65_LMS_CAT16 / lms} * Rec2020_to_LMS_CAT16
    return math3d.mul(math3d.mul(LMS_CAT16_to_Rec2020, m), Rec2020_to_LMS_CAT16)
end

local function selectColorGradingTransformIn()
    return sRGB_to_Rec2020
end

local function selectColorGradingTransformOut()
    return Rec2020_to_sRGB
end

local function selectColorGradingLuminance()
    return LUMINANCE_Rec2020
end

local function ACESLegacyToneMapper(v)
    return ACES(v, 1.0 / 6.0)
end

local tonemapper = ACESLegacyToneMapper

local function scale_luminance(x)
    local luminanceWeights = selectColorGradingLuminance()

    -- Troy Sobotka, 2021, "EVILS - Exposure Value Invariant Luminance Scaling"
    -- https://colab.research.google.com/drive/1iPJzNNKR7PynFmsqSnQm3bCZmQ3CvAJ-#scrollTo=psU43hb-BLzB

    local luminanceIn = math3d.dot(x, luminanceWeights)

    -- TODO: We could optimize for the case of single-channel luminance
    local luminanceOut = math3d.index(tonemapper(luminanceIn), 2) --get the y element, y for luminance value

    local peak = math3d.vec_max(x)
    local chromaRatio = math3d.max(math3d.mul(x, 1.0 / peak), mc.ZERO)

    local chromaRatioLuminance = math3d.dot(chromaRatio, luminanceWeights)

    local chromaRatioReserves = math3d.sub(mc.ONE, chromaRatio)
    local maxReservesLuminance = math3d.dot(chromaRatioReserves, luminanceWeights)

    local luminanceDifference = math.max(luminanceOut - chromaRatioLuminance, 0.0)

    local MINVALUE<const> = -1e-10
    local scaledLuminanceDifference =
            luminanceDifference / math.max(maxReservesLuminance, MINVALUE)

    local chromaScale = (luminanceOut - luminanceDifference) /
            math.max(chromaRatioLuminance, MINVALUE)

    return math3d.add(math3d.mul(chromaScale, chromaRatio), math3d.mul(scaledLuminanceDifference, chromaRatioReserves))
end

local function bake_lut(dim, luminacnce_scaling)
    local cfg = {
        adaptationTransform   = adaptationTransform(0.0, 0.0),
        colorGradingIn        = selectColorGradingTransformIn(),
        colorGradingOut       = selectColorGradingTransformOut(),
        colorGradingLuminance = selectColorGradingLuminance(),
        oetf                  = EOTF_sRGB,
    }

    local tm = luminacnce_scaling and scale_luminance or tonemapper

    local scalor = (1.0 / (dim-1))

    for b=1, dim do
        for g=1, dim do
            for r=1, dim do
                local v = math3d.mul(math3d.vector(r, g, b), scalor)

                -- LogC encoding
                v = LogC_to_linear(v)

                -- Kill negative values near 0.0f due to imprecision in the log conversion
                v = math3d.max(v, 0.0)

                -- if (builder->hasAdjustments) {
                --     // Exposure
                --     v = adjustExposure(v, builder->exposure);

                --     // Purkinje shift ("low-light" vision)
                --     v = scotopicAdaptation(v, builder->nightAdaptation);
                -- }

                -- Move to color grading color space
                v = math3d.transform(cfg.colorGradingIn, v, 0)

                -- if (builder->hasAdjustments) {
                --     -- White balance
                --     v = chromaticAdaptation(v, config.adaptationTransform);

                --     -- Kill negative values before the next transforms
                --     v = max(v, 0.0f);

                --     -- Channel mixer
                --     v = channelMixer(v, builder->outRed, builder->outGreen, builder->outBlue);

                --     -- Shadows/mid-tones/highlights
                --     v = tonalRanges(v, c.colorGradingLuminance,
                --             builder->shadows, builder->midtones, builder->highlights,
                --             builder->tonalRanges);

                --     -- The adjustments below behave better in log space
                --     v = linear_to_LogC(v);

                --     -- ASC CDL
                --     v = colorDecisionList(v, builder->slope, builder->offset, builder->power);

                --     -- Contrast in log space
                --     v = contrast(v, builder->contrast);

                --     -- Back to linear space
                --     v = LogC_to_linear(v);

                --     -- Vibrance in linear space
                --     v = vibrance(v, c.colorGradingLuminance, builder->vibrance);

                --     -- Saturation in linear space
                --     v = saturation(v, c.colorGradingLuminance, builder->saturation);

                --     -- Kill negative values before curves
                --     v = max(v, 0.0f);

                --     -- RGB curves
                --     v = curves(v,
                --             builder->shadowGamma, builder->midPoint, builder->highlightScale);
                -- }

                -- Tone mapping
                v = tm(v)

                -- Go back to display color space
                v = math3d.transform(cfg.colorGradingOut, v, 0)

                -- Apply gamut mapping
                -- if (builder->gamutMapping) {
                --     // TODO: This should depend on the output color space
                --     v = gamutMapping_sRGB(v);
                -- }

                -- TODO: We should convert to the output color space if we use a working
                --       color space that's not sRGB
                -- TODO: Allow the user to customize the output color space

                -- We need to clamp for the output transfer function

                v = mu.saturate(v);

                -- Apply OETF
                v = cfg.oetf(v);
            end
        end
    end

end

local ENABLE_TEST = true
if ENABLE_TEST then
    
end

return {
    bake = bake_lut,
}