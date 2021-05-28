local project = ...
_VFS_ROOT_ = assert(project, "Need project dir.")
package.path = "engine/?.lua"
require "bootstrap"
local cr = import_package "ant.compile_resource"
local ltask = require "ltask"

local S = {}

function S.COMPILE(path)
    return cr.compile_url(path):string()
end

function S.QUIT()
    ltask.quit()
end

return S
