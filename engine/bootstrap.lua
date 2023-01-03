if not __ANT_RUNTIME__ then
    require "editor.init_cpath"
    require "editor.init_vfs"
    require "vfs"
    package.path = package.path:gsub("[^;]+", function (s)
        if s:sub(1,1) ~= "/" then
            s = "/" .. s
        end
        return s
    end)
end

require "common.log"
require "packagemanager"

if __ANT_RUNTIME__ then
    require "runtime.debug"
else
    if package.loaded.math3d then
        error "need init math3d MAXPAGE"
    end
    debug.getregistry().MATH3D_MAXPAGE = 10240
end
