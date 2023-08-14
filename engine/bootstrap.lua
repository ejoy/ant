if not __ANT_RUNTIME__ then
    require "editor.init_vfs"
    package.path = package.path:gsub("[^;]+", function (s)
        if s:sub(1,1) ~= "/" then
            s = "/" .. s
        end
        return s
    end)
end

require "log"
require "packagemanager"

--if __ANT_RUNTIME__ then
--    require "runtime.debug"
--end
