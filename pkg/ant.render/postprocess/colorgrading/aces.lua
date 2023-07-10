local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util

local cs        = require "postprocess.colorgrading.colorspace"

local ycRadiusWeight<const> = 1.75
local TINY<const> = 1e-5
local DIM_SURROUND_GAMMA<const> = 0.9811

local function rgb2saturation(rgb)
    -- Input:  ACES
    -- Output: OCES
    
    local mi = math3d.vec_min(rgb)
    local ma = math3d.vec_max(rgb)
    return (math.max(ma, TINY) - math.max(mi, TINY)) / math.max(ma, 0.01)
end

local function rgb2yc(rgb)
    -- Converts RGB to a luminance proxy, here called YC
    -- YC is ~ Y + K * Chroma
    -- Constant YC is a cone-shaped surface in RGB space, with the tip on the
    -- neutral axis, towards white.
    -- YC is normalized: RGB 1 1 1 maps to YC = 1
    --
    -- ycRadiusWeight defaults to 1.75, although can be overridden in function
    -- call to rgb2yc
    -- ycRadiusWeight = 1 -> YC for pure cyan, magenta, yellow == YC for neutral
    -- of same value
    -- ycRadiusWeight = 2 -> YC for pure red, green, blue  == YC for  neutral of
    -- same value.

    local r, g, b = math3d.index(rgb, 1, 2, 3)

    local chroma = math.sqrt(b * (b - g) + g * (g - r) + r * (r - b))

    return (b + g + r + ycRadiusWeight * chroma) / 3.0
end

local function sign(v)
    return v >= 0 and 1.0 or -1.0
end

local function sigmoid_shaper(x)
    -- Sigmoid function in the range 0 to 1 spanning -2 to +2.
    local t = math.max(1.0 - math.abs(x / 2.0), 0.0)
    local y = 1.0 + sign(x) * (1.0 - t * t);
    return y / 2.0;
end

local function glow_fwd(ycIn, glowGainIn, glowMid)
    if ycIn <= 2.0 / 3.0 * glowMid then
        return glowGainIn
    elseif ycIn >= 2.0 * glowMid then
        return 0.0
    else
        return glowGainIn * (glowMid / ycIn - 1.0 / 2.0)
    end
end

local function rgb2hue(rgb)
    -- Returns a geometric hue angle in degrees (0-360) based on RGB values.
    -- For neutral colors, hue is undefined and the function will return a quiet NaN value.
    local hue = 0.0
    local r, g, b = math3d.index(rgb, 1, 2, 3)
    -- RGB triplets where RGB are equal have an undefined hue
    if not (r == g and g == b) then
        hue = math.deg(math.atan(
                math.sqrt(3.0) * (g - b),
                2.0 * r - g - b))
    end
    return (hue < 0.0) and hue + 360.0 or hue
end

local function center_hue(hue, centerH)
    local hueCentered = hue - centerH
    if hueCentered < -180.0 then
        return hueCentered + 360.0
    elseif hueCentered > 180.0 then
        return hueCentered - 360.0
    else
        return hueCentered;
    end
end

local function darkSurround_to_dimSurround(linearCV)
    local XYZ = math3d.transform(cs.AP1_to_XYZ, linearCV, 0)
    local xyY = cs.XYZ_to_xyY(XYZ)

    local Y = mu.clamp(math3d.index(xyY, 3), 0.0, 1e10)
    xyY = math3d.set_index(xyY, 3, Y ^ DIM_SURROUND_GAMMA)

    XYZ = cs.xyY_to_XYZ(xyY)
    return math3d.transform(cs.XYZ_to_AP1, XYZ, 0)
end

-- "Glow" module constants
local RRT_GLOW_GAIN<const> = 0.05
local RRT_GLOW_MID<const>  = 0.08

-- Red modifier constants
local RRT_RED_SCALE<const> = 0.82
local RRT_RED_PIVOT<const> = 0.03
local RRT_RED_HUE  <const> = 0.0
local RRT_RED_WIDTH<const> = 135.0

-- Desaturation constants
local RRT_SAT_FACTOR<const> = 0.96
local ODT_SAT_FACTOR<const> = 0.93

local function ACES(color, brightness)
    -- Some bits were removed to adapt to our desired output
    local ap0 = math3d.transform(cs.Rec2020_to_AP0, color, 0)

    -- Glow module
    local saturation = rgb2saturation(ap0)
    local ycIn = rgb2yc(ap0)
    local s = sigmoid_shaper((saturation - 0.4) / 0.2)
    local addedGlow = 1.0 + glow_fwd(ycIn, RRT_GLOW_GAIN * s, RRT_GLOW_MID)
    ap0 = math3d.mul(ap0, addedGlow)

    -- Red modifier
    local hue = rgb2hue(ap0)
    local centeredHue = center_hue(hue, RRT_RED_HUE)
    local hueWeight = mu.smoothstep(0.0, 1.0, 1.0 - math.abs(2.0 * centeredHue / RRT_RED_WIDTH))
    hueWeight = hueWeight * hueWeight;

    local ap0r = math3d.index(ap0, 1)
    ap0r = ap0r + hueWeight * saturation * (RRT_RED_PIVOT - ap0r) * (1.0 - RRT_RED_SCALE);
    ap0 = math3d.set_index(ap0, 1, ap0r)

    -- ACES to RGB rendering space
    local ap1 = mu.clamp_vec(math3d.transform(cs.AP0_to_AP1, ap0, 0), mc.ZERO, math3d.vector(1e10, 1e10, 1e10));

    -- Global desaturation
    local dot_luminance_ap1 = math3d.dot(ap1, cs.LUMINANCE_AP1)
    ap1 = math3d.lerp(math3d.vector(dot_luminance_ap1, dot_luminance_ap1, dot_luminance_ap1), ap1, RRT_SAT_FACTOR);

    -- NOTE: This is specific to Filament and added only to match ACES to our legacy tone mapper
    --       which was a fit of ACES in Rec.709 but with a brightness boost.
    ap1 = math3d.mul(ap1, brightness);

    -- Fitting of RRT + ODT (RGB monitor 100 nits dim) from:
    -- https:--github.com/colour-science/colour-unity/blob/master/Assets/Colour/Notebooks/CIECAM02_Unity.ipynb
    local a<const> = 2.785085
    local b<const> = 0.107772
    local c<const> = 2.936045
    local d<const> = 0.887122
    local e<const> = 0.806889
    --local rgbPost = (ap1 * (a * ap1 + b)) / (ap1 * (c * ap1 + d) + e)
    local t0 = math3d.mul(ap1, math3d.muladd(a, ap1, b))
    local t1 = math3d.muladd(ap1, math3d.muladd(c, ap1, d), e)
    local rgbPost = math3d.mul(t0, math3d.reciprocal(t1))

    -- Apply gamma adjustment to compensate for dim surround
    local linearCV = darkSurround_to_dimSurround(rgbPost)

    -- Apply desaturation to compensate for luminance difference
    local dot_cv_luminance = math3d.dot(linearCV, cs.LUMINANCE_AP1)
    linearCV = math3d.lerp(math3d.vector(dot_cv_luminance, dot_cv_luminance, dot_cv_luminance), linearCV, ODT_SAT_FACTOR);

    return math3d.transform(cs.AP1_to_Rec2020, linearCV, 0);
end

return ACES