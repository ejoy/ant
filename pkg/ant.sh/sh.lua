local math3d    = require "math3d"
local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant
local shutil    = require "util"
local sh_rt     = require "sh_rt"

local pi<const>         = math.pi
local inv_pi<const>     = 1.0 / pi
local sqrtpi<const>     = math.sqrt(pi)
local inv_sqrtpi<const> = 1.0 / sqrtpi

local USE_BAKED = true
local A = {
    pi,
    pi * 2.0/ 3.0,
    pi * 1.0 / 4.0,
}

local SHb; do
    local L1_f<const>  = 0.5 * inv_sqrtpi

    local L2_f<const> = math.sqrt(3.0/(4.0*pi))
    local sq15<const>, sq5<const> = math.sqrt(15), math.sqrt(5)
    -- 0.5 for 1/sqrt(4), 0.25 for 1/sqrt(16)
    local L3_f1<const> = sq15*inv_sqrtpi*0.5   --math.sqrt(15.0/( 4.0*pi))
    local L3_f2<const> = sq5 *inv_sqrtpi*0.25  --math.sqrt( 5.0/(16.0*pi))
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

local calc_Yml; do
    local function band1(N)
        return {SHb[1]}
    end

    local function band2(N)
        local Yml = band1(N)
        Yml[2] = SHb[2]*N.y
        Yml[3] = SHb[3]*N.z
        Yml[4] = SHb[4]*N.x
        return Yml
    end

    local function band3(N)
        local Yml = band2(N)
        local x, y, z = N.x, N.y, N.z
        Yml[5] = SHb[5]*y*x
        Yml[6] = SHb[6]*y*z
        Yml[7] = SHb[7]*(3.0*z*z-1.0)
        Yml[8] = SHb[8]*x*z
        Yml[9] = SHb[9]*(x*x-y*y)
        return Yml
    end


    local Yml_calculators = {
        band1, band2, band3
    }
    calc_Yml = function (numband, N)
        local calculator = assert(Yml_calculators[numband], "Invalid bandnum")
        return calculator(N)
    end
end


local ENABLE_TEST = true
if ENABLE_TEST then
    local x, y, z = math3d.index(math3d.normalize(math3d.vector(1, 3, 5)), 1, 2, 3)
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
        local _ = isequal(A[i], sh_rt.A[i]) or error ("One of 'cos(theta): A' is not equal:" ..i)
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

--iu, iv is base 0
local function solidAngle(idim, iu, iv)
    iu, iv = iu-1, iv-1
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

local function Lml_from_str(Lml)
    for i=1, #Lml do
        Lml[i] = math3d.vector(Lml[i])
    end
end

local function create_Lml(bandnum)
    local Lml = {}
    local zero = math3d.serialize(mc.ZERO)
    for i=1, bandnum * bandnum do
        Lml[i] = zero
    end
    return Lml
end

local create_Lml_guard
do
    local mt = {__close=function (Lml)
        for i=1, #Lml do
            Lml[i] = math3d.serialize(Lml[i])
        end
        math3d.recover(Lml.__cp)
        Lml.__cp = nil
    end}
    function create_Lml_guard(Lml)
        Lml_from_str(Lml)
        Lml.__cp = math3d.checkpoint()
        return setmetatable(Lml, mt)
    end
end

local function calc_Lml (cm, bandnum)
    local Lml = create_Lml(bandnum)

    local dim<const>, idim<const> = cm.w, 1.0 / cm.w
    for face=1, 6 do
        for y=1, dim do
            local guard<close> = create_Lml_guard(Lml)
            for x=1, dim do
                local N = m3d_xyz(cm:normal_fxy(face, x, y))
                local color = cm:load_fxy(face, x, y)
                local radiance = math3d.mul(color, solidAngle(idim, x, y))
                local Yml = calc_Yml(bandnum, N)

                for i=1, #Lml do
                    Lml[i] = math3d.add(Lml[i], math3d.mul(radiance, Yml[i]))
                end
            end
        end
    end

    Lml_from_str(Lml)
    return Lml
end

local function render1(Eml, N)
    return Eml[1]
end

local function render4(Eml, N)
    return math3d.add(
        render1(Eml, N),
        math3d.mul(Eml[2], N.y),
        math3d.mul(Eml[3], N.z),
        math3d.mul(Eml[4], N.x))
end

local function render9(Eml, N)
    return math3d.add(
        render4(Eml, N),
        math3d.mul(Eml[5], (N.y * N.x)),
        math3d.mul(Eml[6], (N.y * N.z)),
        math3d.mul(Eml[7], (3.0 * N.z * N.z - 1.0)),
        math3d.mul(Eml[8], (N.z * N.x)),
        math3d.mul(Eml[9], (N.x * N.x - N.y * N.y)))
end

local renderers = {
    [1] = render1,
    [4] = render4,
    [9] = render9
}

local function render_SH(Eml, N)
    N = m3d_xyz(N)
    local renderer = assert(renderers[#Eml], "not support coefficients more than 9")
    local r = renderer(Eml, N)
    return math3d.max(r, mc.ZERO)
end

local function calc_Eml(cm, bandnum)
    local Lml = calc_Lml(cm, bandnum)

    local Eml = {}
    for l=0, bandnum-1 do
        local s = A[l+1] * inv_pi   --pre bake 1/pi
        for m = -l, l do
            local idx = lSHindex0(m, l)
            Eml[idx] = math3d.mul(s * SHb[idx], Lml[idx])
        end
    end

    return Eml
end

-- if false then
--     local texutil = require "ibl.texture"
--     local function create_test_cubemap()
--         local black = ('ffff'):pack(0, 0, 0, 0)
--         local colors = {
--             ('ffff'):pack(1, 1, 1, 0), -- +X /  r  - white
--             ('ffff'):pack(1, 0, 0, 0), -- -X /  l  - red
--             ('ffff'):pack(0, 0, 1, 0), -- +Y /  t  - blue
--             ('ffff'):pack(0, 1, 0, 0), -- -Y /  b  - green
--             ('ffff'):pack(1, 1, 0, 0), -- +Z / fr - yellow
--             ('ffff'):pack(1, 0, 1, 0), -- -Z / bk - magenta
--         };

--         local R, L, T, B, FR, BK = 1, 2, 3, 4, 5, 6

--         local content = {}
--         local dim = 32
--         for f=1, 6 do
--             for y=1, dim do
--                 for x=1, dim do
--                     content[#content+1] = colors[f]
--                 end
--             end
--         end

--         local data = ("c16"):rep(dim*dim*6):pack(table.unpack(content))


--         -- -- 2x2x6
--         -- local data = ("c16"):rep(4 * 6):pack(
--         --     -- black, colors[R],
--         --     -- colors[R], black,

--         --     -- black, colors[L],
--         --     -- colors[L], black,

--         --     -- black, colors[T],
--         --     -- colors[T], black,

--         --     -- black, colors[B],
--         --     -- colors[B], black,

--         --     -- black, colors[FR],
--         --     -- colors[FR], black,

--         --     -- black, colors[BK],
--         --     -- colors[BK], black)
--         --     colors[R], colors[R],
--         --     colors[R], colors[R],

--         --     colors[L], colors[L],
--         --     colors[L], colors[L],

--         --     colors[T], colors[T],
--         --     colors[T], colors[T],

--         --     colors[B], colors[B],
--         --     colors[B], colors[B],

--         --     colors[FR], colors[FR],
--         --     colors[FR], colors[FR],

--         --     colors[BK], colors[BK],
--         --     colors[BK], colors[BK])
--         return texutil.create_cubemap{w=dim,h=dim, texelsize=16,data=data}
--     end

--     local Eml = calc_Eml(create_test_cubemap(), 3)

--     local results = {
--         math3d.tovalue(shutil.render_SH(Eml, math3d.vector( 1.0, 0.0, 0.0))),
--         math3d.tovalue(shutil.render_SH(Eml, math3d.vector(-1.0, 0.0, 0.0))),
--         math3d.tovalue(shutil.render_SH(Eml, math3d.vector( 0.0, 1.0, 0.0))),
--         math3d.tovalue(shutil.render_SH(Eml, math3d.vector( 0.0,-1.0, 0.0))),
--         math3d.tovalue(shutil.render_SH(Eml, math3d.vector( 0.0, 0.0, 1.0))),
--         math3d.tovalue(shutil.render_SH(Eml, math3d.vector( 0.0, 0.0,-1.0))),
--     }
-- end

return {
    calc_Eml    = calc_Eml,
    render_SH   = render_SH,
}
