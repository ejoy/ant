-- m, l is base 0, result base 0
local function SHindex0(m, l)
    return l * (l + 1) + m
end

-- m, l is base 0, result base 1
local function lSHindex0(m, l)
    return SHindex0(m, l) + 1
end

-- m, l is base 1, result base 0
local function SHindex1(m, l)
    return SHindex0(m-1, l-1)
end

-- m, l is base 1, result base 1
local function lSHindex1(m, l)
    return SHindex1(m, 1)+1
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
    factorial2 = function(n, d) return d and F[n]/F[d] or F[n] end
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


return {
    lSHindex0 = lSHindex0,
    factorial2 = factorial2,
}