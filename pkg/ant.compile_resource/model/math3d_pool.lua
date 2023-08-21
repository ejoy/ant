local MATH3D_MAXPAGE <const> = 10240

if package.loaded.math3d then
    error "need init math3d MAXPAGE"
end
debug.getregistry().MATH3D_MAXPAGE = MATH3D_MAXPAGE

local mathpkg = import_package "ant.math"
local math3d = require "math3d"
local pool = {}

local m = {}

function m.alloc(setting)
    if #pool == 0 then
        local obj = math3d.new(MATH3D_MAXPAGE)
        obj.set_homogeneous_depth(setting.hd)
        obj.set_origin_bottom_left(setting.obl)
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

return m
