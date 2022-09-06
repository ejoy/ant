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
    require "vfs.repoaccess" --TODO
end

require "common.log"
