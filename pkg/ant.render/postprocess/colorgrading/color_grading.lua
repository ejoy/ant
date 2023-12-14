local math3d    = require "math3d"
local image     = require "image"
local bgfx      = require "bgfx"
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util
local sampler   = import_package "ant.render.core".sampler
local ACES      = require "postprocess.colorgrading.aces"
local cs        = require "postprocess.colorgrading.colorspace"
local setting   = import_package "ant.settings"
local LUT_DIM<const>        = setting:get "graphic/postprocess/tonemapping/lut_dim"
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

    local x = math3d.index(cs.ILLUMINANT_D65_xyY, 1) - temperature * (temperature < 0.0 and 0.0214 or 0.066)
    local y = chromaticityCoordinateIlluminantD(x) + tint * 0.066

    local lms = math3d.transform(cs.XYZ_to_CIECAT16, cs.xyY_to_XYZ(math3d.vector(x, y, 1.0)), 0)

    local m
    do
        local v = math3d.mul(cs.ILLUMINANT_D65_LMS_CAT16, math3d.reciprocal(lms))
        local x, y, z = math3d.index(v, 1, 2, 3)
        m = math3d.matrix(
            x,   0.0, 0.0, 0.0,
            0.0, y,   0.0, 0.0,
            0.0, 0.0, z,   0.0,
            0.0, 0.0, 0.0, 1.0)
    end

    --LMS_CAT16_to_Rec2020 * mat3f{ILLUMINANT_D65_LMS_CAT16 / lms} * Rec2020_to_LMS_CAT16
    return math3d.mul(math3d.mul(cs.LMS_CAT16_to_Rec2020, m), cs.Rec2020_to_LMS_CAT16)
end

local function selectColorGradingTransformIn()
    return cs.sRGB_to_Rec2020
end

local function selectColorGradingTransformOut()
    return cs.Rec2020_to_sRGB
end

local function selectColorGradingLuminance()
    return cs.LUMINANCE_Rec2020
end

local function ACESLegacyToneMapper(v)
    return ACES(v, 1.0 / 0.6)
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
        oetf                  = cs.OETF_linear,
    }

    local tm = luminacnce_scaling and scale_luminance or tonemapper

    local lastdim = (dim-1)
    local scalor = (1.0 / lastdim)

    local function bake(r, g, b)
        local v = math3d.mul(math3d.vector(r, g, b), scalor)

        -- LogC encoding
        v = cs.LogC_to_linear(v)

        -- Kill negative values near 0.0f due to imprecision in the log conversion
        v = math3d.max(v, mc.ZERO)

        -- Move to color grading color space
        v = math3d.transform(cfg.colorGradingIn, v, 0)

        -- Tone mapping
        v = tm(v)

        -- Go back to display color space
        v = math3d.transform(cfg.colorGradingOut, v, 0)

        v = mu.saturate_vec(v);

        -- Apply OETF
        v = cfg.oetf(v)
        return math3d.serialize(v)
    end

    local results = {}
    for b=0, lastdim do
        for g=0, lastdim do
            local cp = math3d.checkpoint()
            for r=0, lastdim do
                results[#results+1] = bake(r, g, b)
            end
            math3d.recover(cp)
        end
    end

    return table.concat(results, "")
end

local ENABLE_BAKE <const> = false
if ENABLE_BAKE then
    local path = "D://vaststars2/3rd/ant/pkg/ant.resources/textures/color_grading/tonemapping_lut_rg11b10f.dds"
    local r = bake_lut(assert(LUT_DIM))
    local src_fmt, dst_fmt = "RGBA32F", "RG11B10F"
    r = image.pack3dfile(LUT_DIM, LUT_DIM, LUT_DIM, bgfx.memory_buffer(r), src_fmt, dst_fmt)
    local f = assert(io.open(path, "wb"))
    f:write(r)
    f:close()
end

return {
    bake = bake_lut,
}