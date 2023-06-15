local fs        = require "filesystem"
local math3d    = require "math3d"
return {
    loader = function (filename)
        local f = fs.open(fs.path(filename), "rb")
        local c = f:read "a"
        f:close()

        local t = {}
        local numcoeff = c // 16

        -- 3 for bandnum 2, and 7 for bandnum 3
        if numcoeff ~= 3 and numcoeff ~= 7 then
            error(("Invalid irradiance SH coeff:%d, only 4/9(band number: 2/3)"):format(numcoeff))
        end

        for i=1, numcoeff do
            local offset = (i-1)*16+1
            t[i] = math3d.vector(c:sub(offset, 16))
        end
        return t
    end,
    unloader = function (res)

    end
}