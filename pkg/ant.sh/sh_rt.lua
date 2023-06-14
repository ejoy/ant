local shutil = require "util"

local lSHindex0 = shutil.lSHindex0
local factorial2 = shutil.factorial2

local Ki; do
    local INV_QUAT_QI<const>    = (1.0/math.pi)*0.25
    local SQRT_2 <const>        = math.sqrt(2)
    -- sqrt((2*l+1)/4*pi)*sqrt((l-|m|)!/(l+|m|)! ) = sqrt(A/B), A = (2*l+1)*((l-|m|)!), B = 4*pi/((l+|m|)!)
    local function Kml(m, l)
        -- assert(m >= 0) -- m must >= 0
        local K = ((2*l+1)*INV_QUAT_QI)*factorial2(l-m, l+m)
        return math.sqrt(K)
    end

    Ki = setmetatable({}, {__index=function(t, bandnum)
        local k = {}
        for l=0, bandnum-1 do
            k[lSHindex0(0, l)] = Kml(0, l)
            for m = 1, l do
                local v = SQRT_2 * Kml(m, l)
                k[lSHindex0(-m, l)] = v
                k[lSHindex0( m, l)] = v
            end
        end
        t[bandnum] = k
        return k
    end})
end

--[[
    the full formula is:
    Y(m, l) = 
        m > 0, sqrt(2) * K( m , l) * cos( m *phi) * Pml( m ,l)
        m < 0, sqrt(2) * K(|m|, l) * sin(|m|*phi) * Pml(|m|,l)
        m = 0, K(0, l) * Pml(0, l)
    SHb =
        m > 0, cos(m*phi)   * Pml(m,l)
        m < 0, sin(|m|*phi) * Pml(|m|,l)
        m = 0, Pml(0,l)
]]

local calc_SHb; do
    --associated Legendre polynomials
    local function Pi(numband, N)
        local P = {}
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
        P[1] =  Pml_1
        for l=1, numband-1 do
            local Pml = ((2*l-1.0)*Pml_1*N.z - (l-1.0)*Pml_2) / l
            Pml_2 = Pml_1;
            Pml_1 = Pml;
            P[lSHindex0(0, l)] = Pml;
        end

        local Pmm = 1
        for m=1, numband-1 do
            Pmm = (1.0 - 2*m) * Pmm      -- See [1], divide by sqrt(1 - s.z*s.z);
            Pml_2 = Pmm;
            Pml_1 = (2*m + 1.0)*Pmm*N.z
            -- l == m
            P[lSHindex0(-m, m)] = Pml_2
            P[lSHindex0( m, m)] = Pml_2
            if m+1 < numband then
                -- l == m+1
                P[lSHindex0(-m, m+1)] = Pml_1
                P[lSHindex0( m, m+1)] = Pml_1
                for l=m+2, numband-1 do
                    local Pml = ((2*l - 1.0)*Pml_1*N.z - (l + m - 1.0)*Pml_2) / (l-m)
                    Pml_2 = Pml_1
                    Pml_1 = Pml
                    P[lSHindex0(-m, l)] = Pml
                    P[lSHindex0( m, l)] = Pml
                end
            end
        end
        return P
    end

    calc_SHb = function (numBands, N)
        local SHb = Pi(numBands, N)
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
                local idx = lSHindex0(-m, l)
                SHb[idx] = SHb[idx] * Sm

                idx = lSHindex0(m, l)
                SHb[idx] = SHb[idx] * Cm
            end
            local Cm1 = Cm * N.x - Sm * N.y
            local Sm1 = Sm * N.x + Cm * N.y
            Cm = Cm1
            Sm = Sm1
        end

        return SHb
    end
end

local calc_Yml; do
    calc_Yml = function(numband, N)
        local K = Ki[numband]

        local Yml = {}

        local SHb = calc_SHb(numband, N)

        for i=1, numband * numband do
            Yml[i] = K[i] * SHb[i]
        end

        return Yml
    end
end

-- < cos(theta) > SH coefficients pre-multiplied by 1 / K(0,l)
local A; do
    -- l is base 1
    A = setmetatable({}, {__index=function(t, l)
        local R
        -- l base 1
        local ll = l-1
        assert(ll >= 0)
        if ll == 0 then
            R = math.pi
        elseif ll == 1 then
            R = 2 * math.pi / 3;
        elseif 0 ~= (ll & 1) then
            R = 0
        else
            local l_2 = ll // 2;
            local A0 = ((0 ~= l_2 & 1) and 1.0 or -1.0) / ((ll + 2) * (ll - 1))
            local A1 = factorial2(ll, l_2) / (factorial2(l_2) * (1 << ll))
            R = 2 * math.pi * A0 * A1
        end

        t[l] = R
        return R
    end})
end

return {
    A = A,
    Ki = Ki,
    calc_Yml = calc_Yml,
    calc_SHb = calc_SHb,
}

