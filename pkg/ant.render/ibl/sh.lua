local math3d = require "math3d"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant
local function create_cmtexel(w, h, face, x, y)
    return {
        w = w, h = h,
        facenum = w * h,
        face = face, x = x, y = y,
        index = function(self)
            return (self.face-1)*self.facenum+ (self.y-1)*self.w + self.x
        end,
        normal = function(self)
            local function id2uv(iu, iv, w, h)
                return {
                    (iu+0.5)/w,
                    (iv+0.5)/h,
                }
            end

            local function uvface2dir(uv, face)
                if face == 1 then
                    return math3d.vector( 1.0, uv.y,-uv.x);
                elseif face == 2 then
                    return math3d.vector(-1.0, uv.y, uv.x);
                elseif face == 3 then
                    return math3d.vector( uv.x, 1.0,-uv.y);
                elseif face == 4 then
                    return math3d.vector( uv.x,-1.0, uv.y);
                elseif face == 5 then
                    return math3d.vector( uv.x, uv.y, 1.0);
                else
                    assert(face == 6)
                    return math3d.vector(-uv.x, uv.y,-1.0);
                end
            end


            local function n2s(uv)
                return {
                    uv[1]*2.0 - 1.0,
                    uv[2]*2.0 - 1.0,
                }
            end
        
            local uv = n2s(id2uv(self.x, self.y, self.w, self.h));
            return math3d.normalize(uvface2dir(uv, self.face));
        end
    }
end


local function read_cmtexel(cmtexel, data)
    local idx = cmtexel:index()
    local texelsize<const> = 4*3    --sizeof(float) * count(rgb)
    local offset = (idx-1) * texelsize
    local r, g, b = ('fff'):unpack(data, offset)
    return math3d.vector(r, g, b, 0.0)
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
            sphereQuadrantArea(x1, y1);
end

local function SHindex(m, l)
    return l * (l + 1) + m
end

--[[
 * Calculates non-normalized SH bases, i.e.:
 *  m > 0, cos(m*phi)   * P(m,l)
 *  m < 0, sin(|m|*phi) * P(|m|,l)
 *  m = 0, P(0,l)
]]
local function computeShBasics(SHb, numBands, N)
-- #if 0
--     // Reference implementation
--     float phi = atan2(s.x, s.y);
--     for (int l = 0; l < numBands; l++) {
--         SHb[SHindex(0, l)] = Legendre(l, 0, s.z);
--         for (int m = 1; m <= l; m++) {
--             float p = Legendre(l, m, s.z);
--             SHb[SHindex(-m, l)] = std::sin(m * phi) * p;
--             SHb[SHindex( m, l)] = std::cos(m * phi) * p;
--         }
--     }
-- #endif

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
    SHb[0] =  Pml_1
    for l=1, numBands-1 do
        local Pml = ((2*l-1.0)*Pml_1*N.z - (l-1.0)*Pml_2) / l
        Pml_2 = Pml_1;
        Pml_1 = Pml;
        SHb[SHindex(0, l)] = Pml;
    end

    local Pmm = 1
    for m=1, numBands-1 do
        Pmm = (1.0 - 2*m) * Pmm      -- See [1], divide by sqrt(1 - s.z*s.z);
        Pml_2 = Pmm;
        Pml_1 = (2*m + 1.0)*Pmm*N.z
        -- l == m
        SHb[SHindex(-m, m)] = Pml_2
        SHb[SHindex( m, m)] = Pml_2
        if m+1 < numBands then
            -- l == m+1
            SHb[SHindex(-m, m+1)] = Pml_1
            SHb[SHindex( m, m+1)] = Pml_1
            for l=m+2, numBands do
                local Pml = ((2*l - 1.0)*Pml_1*N.z - (l + m - 1.0)*Pml_2) / (l-m)
                Pml_2 = Pml_1
                Pml_1 = Pml
                SHb[SHindex(-m, l)] = Pml
                SHb[SHindex( m, l)] = Pml
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
            local idx = SHindex(-m, l)
            SHb[idx] = SHb[idx] * Sm

            idx = SHindex(m, l)
            SHb[idx] = SHb[idx] * Cm
        end
        local Cm1 = Cm * N.x - Sm * N.y
        local Sm1 = Sm * N.x + Cm * N.y
        Cm = Cm1
        Sm = Sm1
    end
end

local function SHindex(m, l)
    return l * (l + 1) + m + 1
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
                k[SHindex(m, l)] = sqrt2 * Kml(m, l)
            end
        end
        t[bandnum] = k
        return k
    end})
    Ki = function(bandnum) return K[bandnum] end
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

local function LiSH (cm, bandnum)
    local cmtexel = create_cmtexel(cm.w, cm.h, 1, 1, 1)
    local coeffnum = bandnum * bandnum
    local SH = {}
    for i=1, coeffnum do
        SH[i] = math3d.ref(mc.ZERO)
    end
    for face=1, 6 do
        cmtexel.face = face
        math3d.reset()
        for y=1, cm.w do
            cmtexel.y = y
            for x=1, cm.h do
                cmtexel.x = x
                local N = cmtexel:normal()
                local Li = read_cmtexel(cmtexel, cm.data)

                Li = math3d.mul(Li, solidAngle(cmtexel.w, x, y))

                local SHb = {}
                for i=1, coeffnum do
                    SHb[i] = 0.0
                end
                computeShBasics(SHb, bandnum, N)

                for i=1, coeffnum do
                    SH[i].v = math3d.add(SH[i], math3d.mul(Li, SHb[i]))
                end
            end
        end
    end

    return SH
end



return function (cm, bandnum)
    local K = Ki(bandnum)
    local Li = LiSH(cm, bandnum)

    for l=0, bandnum-1 do
        local cosSH = compute_cos_SH(l)
        for m = -l, l do
            local idx = SHindex(m, l)
            Li[idx].v = math3d.mul(K[idx] * cosSH, Li[idx])
        end
    end

    return Li
end
