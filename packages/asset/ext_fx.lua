local respath = require "respath"
local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"

local function init(fxc)
    local newfx = {setting=fxc.setting or {}}
    local function check_resolve_path(p)
        if fxc[p] then
            newfx[p] = respath.absolute_path(fxc[p])
        end
    end
    check_resolve_path "varying_path"
    check_resolve_path "vs"
    check_resolve_path "fs"
    check_resolve_path "cs"
    return cr.load_fx(newfx)
end

return {
    init = init,
    loader = function (fx, world)
        local fxc = serialize.parse(fx, cr.read_file(fx))
        return init(fxc)
    end,
    unloader = function (res)
    end
}