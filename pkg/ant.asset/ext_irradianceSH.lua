local fs        = require "filesystem"
local lfs       = require "filesystem.local"

local math3d    = require "math3d"
local async		= require "async"

local function read_file(p)
    local f<close> = assert(lfs.open(lfs.path(p), "rb"), ("Invalid filename:%s"):format(p))
    return f:read "a"
end

return {
    loader = function (filename)
        local c = read_file(async.compile(filename .. "|main.bin"))

        local t = {}
        local numcoeff = #c // 16

        -- 3 for bandnum 2, and 7 for bandnum 3
        if numcoeff ~= 3 and numcoeff ~= 7 then
            error(("Invalid irradiance SH coeff:%d, only 4/9(band number: 2/3)"):format(numcoeff))
        end

        for i=1, numcoeff do
            local offset = (i-1)*16
            t[i] = math3d.vector(c:sub(offset+1, offset+16))
        end
        return t
    end,
    unloader = function (res)

    end
}