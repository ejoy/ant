debug.setcstacklimit(200)

if not __ANT_RUNTIME__ then
    require "editor"
    return
end

require "common.init_bgfx"
require "common.window"
require 'runtime.vfs'
require 'runtime.errlog'
require "common.sort_pairs"
local pm = require "antpm"
pm.initialize()
import_package = pm.import
import_package "ant.asset".init()
require 'runtime.debug'
require "filesystem"
