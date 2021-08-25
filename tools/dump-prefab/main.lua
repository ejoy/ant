if arg[1] then
    _VFS_ROOT_ = arg[1]
    package.path = "engine/?.lua"
    require "editor.init_vfs"
    local lfs = require "filesystem.local"
    local vfs = require "vfs"
    local workdir = lfs.absolute(lfs.path(arg[0])):remove_filename()
    vfs.mount("pkg/tools.dump-prefab", workdir:string())
end

package.path = "engine/?.lua"
require "bootstrap"
import_package "tools.dump-prefab"
