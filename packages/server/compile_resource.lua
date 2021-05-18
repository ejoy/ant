local project, path = ...
_VFS_ROOT_ = assert(project, "Need project dir.")
package.path = "engine/?.lua"
require "bootstrap"
local cr = import_package "ant.compile_resource"
cr.compile_url(path)
