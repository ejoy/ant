if package.loaded.math3d then
    error "need init math3d MAXPAGE"
end
debug.getregistry().MATH3D_MAXPAGE = 10240

local mathpkg = import_package "ant.math"
local math3d = require "math3d"
local pool = {}

local m = {}

function m.alloc()
    if #pool == 0 then
        local obj = math3d.new()
        mathpkg.init(obj)
        return obj
    end
    local obj = pool[#pool]
    pool[#pool] = nil
    return obj
end

function m.free(obj)
    obj.reset()
    pool[#pool+1] = obj
end

m.free(math3d)

return m
