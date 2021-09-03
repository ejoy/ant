package.path = "engine/?.lua"

if arg[1] then
    _VFS_ROOT_ = arg[1]
    require "editor.init_vfs"
    local lfs = require "filesystem.local"
    local vfs = require "vfs"
    local workdir = lfs.absolute(lfs.path(arg[0])):remove_filename()
    vfs.mount("pkg/tools.dump-prefab", workdir:string())
end

require "bootstrap"
local default_baker = "path_tracer"
if default_baker == "path_tracer" then
    import_package "ant.tool.baker"
else
    import_package "ant.window".start "ant.tool.baker"
end