debug.setcstacklimit(200)

if __ANT_RUNTIME__ then
    require "runtime.vfs"
    require "runtime.errlog"
else
    require "editor.init_cpath"
    require "editor.vfs"
    require "editor.log"
end

require "common.init_bgfx"
require "filesystem"

local pm = require "antpm"
pm.initialize()
import_package = pm.import
import_package "ant.asset".init()

if __ANT_RUNTIME__ then
    require "runtime.debug"
end
