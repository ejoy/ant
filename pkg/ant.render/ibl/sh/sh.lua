local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant
local shutil    = require "ibl.sh.util"
local sh_rt     = require "ibl.sh.sh_rt"

local USE_BAKED = true
local A = {
    math.pi,
    math.pi * 2.0/ 3.0,
    math.pi * 1.0 / 4.0,
}

local pi<const>         = math.pi
local sqrtpi<const>     = math.sqrt(pi)
local inv_sqrtpi<const> = 1.0 / sqrtpi

local SHb; do
    local L1_f<const>  = 0.5 * inv_sqrtpi

    local L2_f<const> = math.sqrt(3.0/(4.0*pi))
    local sq15<const>, sq5<const> = math.sqrt(15), math.sqrt(5)
    -- 0.5 for 1/sqrt(4), 0.25 for 1/sqrt(16)
    local L3_f1<const> = sq15*inv_sqrtpi*0.5   --math.sqrt(15.0/(4.0*pi))
    local L3_f2<const> = sq5*inv_sqrtpi*0.25   --math.sqrt(5.0/(16.0*pi))
    local L3_f3<const> = sq15*inv_sqrtpi*0.25  --math.sqrt(15.0/(16.0*pi))
    
    SHb = {
         L1_f,

        -L2_f,
         L2_f,
        -L2_f,

         L3_f1,
        -L3_f1,
         L3_f2,
        -L3_f1,
         L3_f3,
    }
end

local function calc_Yml(numband, N)
    local Yml = {}

    Yml[1] = SHb[1]

    local x, y, z = N.x, N.y, N.z

    if numband >= 2 then
        Yml[2] = SHb[2]*y
        Yml[3] = SHb[3]*z
        Yml[4] = SHb[4]*x
    end

    if numband >= 3 then
        local x2, y2, z2 = x*x, y*y, z*z
        Yml[5] = SHb[5]*y*x
        Yml[6] = SHb[6]*y*z
        Yml[7] = SHb[7]*(3.0*z2-1.0)
        Yml[8] = SHb[8]*x*z
        Yml[9] = SHb[9]*(x2-y2)
    end

    return Yml
end

local ENABLE_TEST = true
if ENABLE_TEST then
    local x, y, z = math3d.index(math3d.normalize(math3d.vector(1, 1, 1)), 1, 2, 3)
    local N = {x=x, y=y, z=z}
    local result1 = calc_Yml(3, N)

    local result2 = sh_rt.calc_Yml(3, N)

    assert(#result1 == #result2, "Not sample number with 'calc_Yml'")

    local function isequal(lhs, rhs)
        return math.abs(lhs-rhs) <= 1e-6
    end
    for i=1, #result1 do
        assert(isequal(result1[i], result2[i]), "One of result in 'calc_Yml' is not equal")
    end

    for i=1, #A do
        assert(isequal(A[i], sh_rt.A[i]), "One of 'cos(theta): A' is not equal:" ..i)
    end
end

if not USE_BAKED then
    A = sh_rt.A
    calc_Yml = sh_rt.calc_Yml
end

--[[
 * Area of a cube face's quadrant projected onto a sphere
 *
 *  1 +---+----------+
 *    |   |          |
 *    |---+----------|
 *    |   |(x,y)     |
 *    |   |          |
 *    |   |          |
 * -1 +---+----------+
 *   -1              1
 *
 *
 * The quadrant (-1,1)-(x,y) is projected onto the unit sphere
 *
]]
local function sphereQuadrantArea(x, y)
    return math.atan(x*y, math.sqrt(x*x + y*y + 1))
end

local function solidAngle(dim, iu, iv)
    local idim = 1.0 / dim;
    local s = ((iu + 0.5) * 2.0 * idim)-1.0
    local t = ((iv + 0.5) * 2.0 * idim)-1.0

    local x0, y0 = s-idim, t-idim
    local x1, y1 = s+idim, t+idim

    return  sphereQuadrantArea(x0, y0) -
            sphereQuadrantArea(x0, y1) -
            sphereQuadrantArea(x1, y0) +
            sphereQuadrantArea(x1, y1)
end

local lSHindex0 = shutil.lSHindex0

--[[
    using SH for irradiance, we need two step:
        1. compress, projection the irradiance map to Eml with SH basics function
        2. render, use the compress Eml value with sample direction(the normal value), and reprojection the Eml with SH basics function to get the irradiance value
    see the reference: 'An efficient Representation for Irradiance Environment Maps'[1]

    what are l and m mean:
        l for level, m:[-l, l], we say 3 level sh, it mean lmax = 3, so, total sh number: l^2
        for example: l = 3, sh number is: l^2 = 9, where level 1 has one element, level 2 have 3 elements, level 3 have 5 elements, 1 + 3 + 5 = 9

    the 'sh.lua' file, only for compress irradiance map, the render part is in ibl.sh file, defined by 'IRRADIANCE_SH_BAND_NUM'

    Kml = K(m, l) = sqrt(A/B), where:
            A = (2l+1)*(l-|m|)! = (2l+1) * factorial(l-abs(m))
            B =   4*pi*(l+|m|)! =   4*pi * factorial(l+abs(m))
    
    Yml(theta, phi) = Kml * e^(i*m*phi) * P|m|l(cos(theta)), where:
        m > 0, sqrt(2) * Kml * cos(m*phi)   * Pml(cos(theta))
        m < 0, sqrt(2) * Kml * sin(|m|*phi) * P-ml(cos(theta))
        m = 0, K0l * P0l(cos(theta))

        Yml(theta, phi) has another version defined in Cartesian coordinates space:
            (x, y, z) = (sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta))
            Y00(theta, phi)                 = 0.282095
            (Y11; Y10; Y1-1)(theta, phi)    = 0.488603*(x; z; y)
            (Y21; Y2-1;Y2-2)(theta, phi)    = 1.092548*(xz;yz;xy)
            Y20(theta, phi)                 = 0.315392*(3*z*z-1)
            Y22(theta, phi)                 = 0.546274*(x*x-y*y)

            !!Y11; Y10;Y1-1; these symbols use Ylm, they reverse m and l order in suffix, so using Yml, Y11 = Y11, Y10 = Y01, Y1-1 = Y-11
        those constant value:
            0.282095 = K(0, 0) = sqrt(1/(2*pi))
            0.488603 = K(-1, 1) = K(0, 1) = K(1, 1) = A = (2*1+1) * 0! = 3, B = 4*pi*0!= 4*pi; Kml = sqrt(A/B) = sqrt(3/(4*pi))
            ...

    Kml = K( m , l) ==> K0l = K(0, l)
    Yml = Y(|m|, l) ==> Y0l = Y(0, l)
    here, Yml is Associated Legendre polynomials, sometime we call Yml as Pml, they point to the same meanings

    the compress part of SH formula:
        E = integral[omega](Li * cos(theta) * domega)
            the E is the irradiance at some point, cos(theta) is the normal dot soild angle direction
            and BRDF is miss here, bacause the reflection and visibility are ignore here, so only Li and cos(theta) will affect the result
        
        so, we need to use SH basics function Yml to weight Li and cos(theta), which is Lml and Al: 
            L = integral[omega](Li(theta, phi) * Yml(theta, phi) * domega) ==> Lml = Sum(Li(theta, phi) * Yml(theta, phi) * SolidAngle(theta, phi))

            (we use '==>' here, not '=', because L is not equal to Lml)

            A = integral[omega](cos(theta) * Yml(theta, phi) * domega) ==> Al = Sum(cos(theta) * Yml(theta, phi))
                Al has some special features we can use. Because A = (normal dot solid angle direction), so A has no azimuthal dependence, then
                    only m = 0 is valid for any l index. so we write Al not A0l, just for convenient

                we make:
                    Al* = sqrt(4*math.pi/(2l+1)) * Al
                Beside this, Al has an analytic formula(see the reference[2] for how to derived), we can derived, when:
                    l = 1: Al* = 2*math.pi/3
                    l > 1, odd: Al* = 0
                          even: Al* = (2*math.pi)*(-1)^(l/2-1)/(l+2)(l+1)*((l!/(2^l*((l/2)!)^2)))
            
        then, we get what we need, so:
            Eml = Sum(Lml * Al*)
                Bml = albedo * Eml, where albedo is the material color, i.e. from base color texture
                    the Bml is the output color(irradiance value) of this point

                if bandnum = 2/3, Eml is 4/9 coefficients with RGB values

    the render part of SH:
        here is come to the magic of SH base functions. 
        multiply the compress value with the base function Yml, we can get the approximation of E, which is Eml.
            (of cause, if we get l to inifinte value, E is equal to Eml)
        we need to use Eml to recover E, so:
            E = Sum(Eml * Yml(theta, phi))  -- all the (theta, phi) paris mean it's a direction that is normal value of the sample point

    References:
    [1] An efficient Representation for Irradiance Environment Maps
    [2] R. Ramamoorthi and P. Hanrahan. On the relationship between radiance and irradiance: Determining the illumination from images of a convex lambertian object. To appear, Journal of the Optical Society of America A, 2001
]]

local function m3d_xyz(v)
    local x, y, z = math3d.index(v, 1, 2, 3)
    return {x=x, y=y, z=z}
end

local function calc_Lml (cm, bandnum)
    local coeffnum = bandnum * bandnum
    local Lml = {}
    for i=1, coeffnum do
        Lml[i] = mc.ZERO
    end
    for face=1, 6 do
        for y=1, cm.w do
            for x=1, cm.h do
                local N = m3d_xyz(cm:normal_fxy(face, x, y))

                local color = cm:load_fxy(face, x, y)

                color = math3d.mul(color, solidAngle(cm.w, x, y))

                local Yml = calc_Yml(bandnum, N)

                for i=1, coeffnum do
                    Lml[i] = math3d.add(Lml[i], math3d.mul(color, Yml[i]))
                end
            end
        end
    end

    return Lml
end

return {
    calc_Eml = function (cm, bandnum)
        local Lml = calc_Lml(cm, bandnum)

        local Eml = {}
        for l=0, bandnum-1 do
            local s = A[l+1] * inv_sqrtpi   --pre bake 1/pi
            for m = -l, l do
                local idx = lSHindex0(m, l)
                Eml[idx] = math3d.mul(s * SHb[idx], Lml[idx])
            end
        end

        return Eml
    end,
    render_SH = function(Eml, N)
        N = m3d_xyz(N)

        local num_coeffs = #Eml
        if num_coeffs > 9 then
            error("not support coefficients more than 9")
        end

        local r
        if num_coeffs >= 1 then
            r = Eml[1]
        end

        if num_coeffs >= 4 then
            r = math3d.add(
                r,
                math3d.mul(Eml[2], N.y),
                math3d.mul(Eml[3], N.z),
                math3d.mul(Eml[4], N.x))
        end

        if num_coeffs >= 9 then
            r = math3d.add(
                r,
                math3d.mul(Eml[5], (N.y * N.x)),
                math3d.mul(Eml[6], (N.y * N.z)),
                math3d.mul(Eml[7], (3.0 * N.z * N.z - 1.0)),
                math3d.mul(Eml[8], (N.z * N.x)),
                math3d.mul(Eml[9], (N.x * N.x - N.y * N.y)))
        end

        local x,y,z = math3d.index(r, 1, 2, 3)
        x, y, z = math.max(x, 0.0), math.max(y, 0.0), math.max(z, 0.0)
        return math3d.vector(x, y, z, 0.0)
    end,
}
