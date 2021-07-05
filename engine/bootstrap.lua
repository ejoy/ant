if __ANT_RUNTIME__ then
else
    require "editor.init_cpath"
    require "editor.init_vfs"
    require "vfs"

    --TODO
    require "vfs.repoaccess"
end

require "common.log"
require "common.init_bgfx"
require "filesystem"
require "packagemanager"

if __ANT_RUNTIME__ then
    --require "runtime.debug"
end
