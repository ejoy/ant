local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
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

local function SHindex(m, l)
    return l * (l + 1) + m
end

local function lSHindex(m, l)
    return SHindex(m, l) + 1
end

local factorial1, factorial2; do
    local F = setmetatable({}, {__index=function (t, n)
        local v = 1.0
        if n > 1 then
            for i=1, n do
                v = v * i
            end
        end

        t[n] = v
        return v
    end})
    factorial1 = function(n) return F[n] end
    factorial2 = function(n, d) return F[n]/F[d] end
end

local function factorial(n, d)
    d = d or 1

    d = math.max(1, d)
    n = math.max(1, n)
    local r = 1.0
    if n == d then
        -- intentionally left blank 
    elseif n > d then
        while n > d do
            r = r * n
            n = n - 1
        end
    else
        while d > n do
            r = r * d
            d = d - 1
        end
        r = 1.0 / r
    end
    return r
end

local Ki; do
    --   sqrt((2*l + 1) / 4*pi) * sqrt( (l-|m|)! / (l+|m|)! )
    local function Kml(m, l)
        m = math.abs(m)
        local K = (2 * l + 1) * factorial2(l - m, l + m) * (1.0 / math.pi) * 0.25
        return math.sqrt(K)
    end

    local K = setmetatable({}, {__index=function(t, bandnum)
        local k = {}
        local sqrt2 = math.sqrt(2)
        for l=0, bandnum-1 do
            for m = -l, l do
                k[lSHindex(m, l)] = sqrt2 * Kml(m, l)
            end
        end
        t[bandnum] = k
        return k
    end})
    Ki = function(bandnum) return K[bandnum] end
end

--[[
    SHb:
    m > 0, cos(m*phi)   * P(m,l)
    m < 0, sin(|m|*phi) * P(|m|,l)
    m = 0, P(0,l)

    Pml is associated Legendre polynomials
]]
local function computeShBasics(numBands, N)
    local SHb = {}
--     Reference implementation
--     local phi = math.atan(s.x, s.y);
--     for l=0, numBands-1 do
--         SHb[SHindex(0, l)] = Legendre(l, 0, s.z)
--         for m = 1, l do
--             float p = Legendre(l, m, s.z);
--             SHb[SHindex(-m, l)] = math.sin(m * phi) * p
--             SHb[SHindex( m, l)] = math.cos(m * phi) * p
--         end
--     end

    --[[
     * Below, we compute the associated Legendre polynomials using recursion.
     * see: http://mathworld.wolfram.com/AssociatedLegendrePolynomial.html
     *
     * Note [0]: s.z == cos(theta) ==> we only need to compute P(s.z)
     *
     * Note [1]: We in fact compute P(s.z) / sin(theta)^|m|, by removing
     * the "sqrt(1 - s.z*s.z)" [i.e.: sin(theta)] factor from the recursion.
     * This is later corrected in the ( cos(m*phi), sin(m*phi) ) recursion.
    ]]

    -- s = (x, y, z) = (sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta))

    -- handle m=0 separately, since it produces only one coefficient
    local Pml_2, Pml_1 = 0, 1
    SHb[1] =  Pml_1
    for l=1, numBands-1 do
        local Pml = ((2*l-1.0)*Pml_1*N.z - (l-1.0)*Pml_2) / l
        Pml_2 = Pml_1;
        Pml_1 = Pml;
        SHb[lSHindex(0, l)] = Pml;
    end

    local Pmm = 1
    for m=1, numBands-1 do
        Pmm = (1.0 - 2*m) * Pmm      -- See [1], divide by sqrt(1 - s.z*s.z);
        Pml_2 = Pmm;
        Pml_1 = (2*m + 1.0)*Pmm*N.z
        -- l == m
        SHb[lSHindex(-m, m)] = Pml_2
        SHb[lSHindex( m, m)] = Pml_2
        if m+1 < numBands then
            -- l == m+1
            SHb[lSHindex(-m, m+1)] = Pml_1
            SHb[lSHindex( m, m+1)] = Pml_1
            for l=m+2, numBands-1 do
                local Pml = ((2*l - 1.0)*Pml_1*N.z - (l + m - 1.0)*Pml_2) / (l-m)
                Pml_2 = Pml_1
                Pml_1 = Pml
                SHb[lSHindex(-m, l)] = Pml
                SHb[lSHindex( m, l)] = Pml
            end
        end
    end

    --  At this point, SHb contains the associated Legendre polynomials divided
    --  by sin(theta)^|m|. Below we compute the SH basis.
    -- 
    --  ( cos(m*phi), sin(m*phi) ) recursion:
    --  cos(m*phi + phi) == cos(m*phi)*cos(phi) - sin(m*phi)*sin(phi)
    --  sin(m*phi + phi) == sin(m*phi)*cos(phi) + cos(m*phi)*sin(phi)
    --  cos[m+1] == cos[m]*s.x - sin[m]*s.y
    --  sin[m+1] == sin[m]*s.x + cos[m]*s.y
    -- 
    --  Note that (d.x, d.y) == (cos(phi), sin(phi)) * sin(theta), so the
    --  code below actually evaluates:
    --       (cos((m*phi), sin(m*phi)) * sin(theta)^|m|
    local Cm, Sm = N.x, N.y
    for m=1, numBands do
        for l = m, numBands-1 do
            local idx = lSHindex(-m, l)
            SHb[idx] = SHb[idx] * Sm

            idx = lSHindex(m, l)
            SHb[idx] = SHb[idx] * Cm
        end
        local Cm1 = Cm * N.x - Sm * N.y
        local Sm1 = Sm * N.x + Cm * N.y
        Cm = Cm1
        Sm = Sm1
    end

    return SHb
end

-- < cos(theta) > SH coefficients pre-multiplied by 1 / K(0,l)
local compute_cos_SH; do
    local COS = setmetatable({}, {__index=function(t, l)
        local R
        if l == 0 then
            R = math.pi
        elseif (l == 1) then
            R = 2 * math.pi / 3;
        elseif l & 1 then
            R = 0
        else
            local l_2 = l // 2;
            local A0 = ((l_2 & 1) and 1.0 and -1.0) / ((l + 2) * (l - 1))
            local A1 = factorial2(l, l_2) / (factorial2(l_2) * (1 << l))
            R = 2 * math.pi * A0 * A1
        end

        t[l] = R
        return R
    end})

    compute_cos_SH = function (l)
        return COS[l]
    end
end

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

local function LiSH (cm, bandnum)
    local coeffnum = bandnum * bandnum
    local SH = {}
    for i=1, coeffnum do
        SH[i] = math3d.ref(mc.ZERO)
    end
    for face=1, 6 do
        for y=1, cm.w do
            for x=1, cm.h do
                local N = m3d_xyz(cm:normal_fxy(face, x, y))

                local color = cm:load_fxy(face, x, y)

                color = math3d.mul(color, solidAngle(cm.w, x, y))

                local SHb = computeShBasics(bandnum, N)

                for i=1, coeffnum do
                    SH[i].v = math3d.add(SH[i], math3d.mul(color, SHb[i]))
                end
            end
        end
    end

    return SH
end

return {
    calc_Eml = function (cm, bandnum)
        local K = Ki(bandnum)
        local Lml = LiSH(cm, bandnum)

        local Eml = {}
        for l=0, bandnum-1 do
            local A = compute_cos_SH(l)
            for m = -l, l do
                local idx = lSHindex(m, l)
                Eml[idx] = math3d.mul(K[idx] * A, Lml[idx])
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
