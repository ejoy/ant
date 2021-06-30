if __ANT_RUNTIME__ then
    require "runtime.vfs"
else
    require "editor.init_cpath"
    if not _VFS_ROOT_ and arg then
        local lfs = require "filesystem.local"
        _VFS_ROOT_ = lfs.absolute(lfs.path(arg[0])):remove_filename():string()
    end
    require "editor.vfs"
end

require "common.log"
require "common.init_bgfx"
require "filesystem"
require "packagemanager"

if __ANT_RUNTIME__ then
    --require "runtime.debug"
end
