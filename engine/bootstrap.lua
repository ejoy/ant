if not __ANT_RUNTIME__ then
    require "editor.init_cpath"
    require "editor.init_vfs"
    require "vfs"
    require "vfs.repoaccess" --TODO
end

require "common.log"
require "packagemanager"
