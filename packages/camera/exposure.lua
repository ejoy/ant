local ecs   = ...
local world = ecs.world
local w     = world.w

--[[
    exposure setting from filament, document:
    https://google.github.io/filament/Filament.html#imagingpipeline/physicallybasedcamera

    code from:
    filament/src/Exposure.cpp
]]

local ie = ecs.interface "iexposure"

local default_exposure<const> = {
    type            = "Auto",  --Auto, Manaual, SBS, SOS, only support Auto and Manual right now
    manual_ev       = -16.0,
    aperture        = 16.0, --mean f/16.0
    ISO             = 100.0,
    shutter_speed   = 1.0/60.0,
    auto_exposure_key= 0.115,
    adaptaion_rate   = 0.5,
    -- --DOF
    -- FilmSize        = 35.0, --unit is: mm
    -- FocalLength     = 35.0, --unit is: mm, dof
    -- FocusDistance   = 10.0, --unit is: m
    -- NumBlades       = 5,
}

local function exposure(cref)
    w:sync("exposure:in", cref)
    return cref.exposure
end

local function _EV(e)
    local N = e.aperture
    local t = e.shutter_speed
    local S = e.ISO
    return (N * N) / t * 100.0 / S
end

function ie.ev100(cref)
    local e = exposure(cref)
    --[[
        With N = aperture, t = shutter speed and S = sensitivity(ISO),
        we can compute EV100 knowing that:

        EVs = log2(N^2 / t)
        and
        EVs = EV100 + log2(S / 100)

        We can therefore find:

        EV100 = EVs - log2(S / 100)
        EV100 = log2(N^2 / t) - log2(S / 100)
        EV100 = log2((N^2 / t) * (100 / S))

        Reference: https://en.wikipedia.org/wiki/Exposure_value
    ]]
    return math.log(_EV(e), 2)
end

function ie.ev100_from_luminance(luminance)
    --[[
        With L the average scene luminance, S the sensitivity and K the
        reflected-light meter calibration constant:

        EV = log2(L * S / K)

        With the usual value K = 12.5 (to match standard camera manufacturers
        settings), computing the EV100 becomes:

        EV100 = log2(L * 100 / 12.5)

        Reference: https://en.wikipedia.org/wiki/Exposure_value
    ]]

    local K<const> = 100.0 / 12.5
    return math.log(luminance * K, 2)
end

function ie.ev100_from_illuminance(illuminance)
    --[[
         With E the illuminance, S the sensitivity and C the incident-light meter
         calibration constant, the exposure value can be computed as such:
        
         EV = log2(E * S / C)
         or
         EV100 = log2(E * 100 / C)
        
         Using C = 250 (a typical value for a flat sensor), the relationship between
         EV100 and illuminance is:
        
         EV100 = log2(E * 100 / 250)
        
         Reference: https://en.wikipedia.org/wiki/Exposure_value
    ]]

    local C<const> = 100.0 / 250.0
    return math.log(illuminance * C, 2)
end
    
function ie.exposure(cref)
    -- This is equivalent to calling exposure(ev100(N, t, S))
    -- By merging the two calls we can remove extra pow()/log2() calls
    local e = exposure(cref)
    return 1.0 / (1.2 * _EV(e));
end
    
function ie.exposure_from_ev100(ev100)
--[[
    The photometric exposure H is defined by:

    H = (q * t / (N^2)) * L

    Where t is the shutter speed, N the aperture, L the incident luminance
    and q the lens and vignetting attenuation. A typical value of q is 0.65
    (see reference link below).

    The value of H as recorded by a sensor depends on the sensitivity of the
    sensor. An easy way to find that value is to use the saturation-based
    sensitivity method:

    S_sat = 78 / H_sat

    This method defines the maximum possible exposure that does not lead to
    clipping or blooming.

    The factor 78 is chosen so that exposure settings based on a standard
    light meter and an 18% reflective surface will result in an image with
    a grey level of 18% * sqrt(2) = 12.7% of saturation. The sqrt(2) factor
    is used to account for an extra half a stop of headroom to deal with
    specular reflections.

    Using the definitions of H and S_sat, we can derive the formula to
    compute the maximum luminance to saturate the sensor:

    H_sat = 78 / S_stat
    (q * t / (N^2)) * Lmax = 78 / S
    Lmax = (78 / S) * (N^2 / (q * t))
    Lmax = (78 / (S * q)) * (N^2 / t)

    With q = 0.65, S = 100 and EVs = log2(N^2 / t) (in this case EVs = EV100):

    Lmax = (78 / (100 * 0.65)) * 2^EV100
    Lmax = 1.2 * 2^EV100

    The value of a pixel in the fragment shader can be computed by
    normalizing the incident luminance L at the pixel's position
    with the maximum luminance Lmax

    Reference: https://en.wikipedia.org/wiki/Film_speed
]]

    return 1.0 / (1.2 * 2.0^ev100)
end

function ie.luminance(cref)
    -- This is equivalent to calling luminance(ev100(N, t, S))
    -- By merging the two calls we can remove extra pow()/log2() calls
    local e = exposure(cref)
    return _EV(e) * 0.125;
end

function ie.luminance_from_ev100(ev100)
    --[[
        With L the average scene luminance, S the sensitivity and K the
        reflected-light meter calibration constant:

        EV = log2(L * S / K)
        L = 2^EV100 * K / 100

        As in ev100FromLuminance(luminance), we use K = 12.5 to match common camera
        manufacturers (Canon, Nikon and Sekonic):

        L = 2^EV100 * 12.5 / 100 = 2^EV100 * 0.125

        With log2(0.125) = -3 we have:

        L = 2^(EV100 - 3)

        Reference: https://en.wikipedia.org/wiki/Exposure_value
    ]]

    return 2.0^(ev100 - 3.0);
end

function ie.illuminance(cref)
    -- This is equivalent to calling illuminance(ev100(N, t, S))
    -- By merging the two calls we can remove extra pow()/log2() calls
    local e = exposure(cref)
    return 2.5 * _EV(e)
end

function ie.illuminance_from_ev100(ev100)
    --[[
        With E the illuminance, S the sensitivity and C the incident-light meter
        calibration constant, the exposure value can be computed as such:

        EV = log2(E * S / C)
        or
        EV100 = log2(E * 100 / C)

        Using C = 250 (a typical value for a flat sensor), the relationship between
        EV100 and illuminance is:

        EV100 = log2(E * 100 / 250)
        E = 2^EV100 / (100 / 250)
        E = 2.5 * 2^EV100

        Reference: https://en.wikipedia.org/wiki/Exposure_value
    ]]

    return 2.5*(2.0^ev100)
end

