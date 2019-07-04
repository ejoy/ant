if not __ANT_RUNTIME__ then
    return require "editor"
end

require 'runtime.vfs'
require 'runtime.errlog'
local pm = require "antpm"
pm.init()
import_package = pm.import
require 'runtime.debug'
require "filesystem"
require "vfs.fileconvert.glTF"
return import_package "ant.imgui".runtime
