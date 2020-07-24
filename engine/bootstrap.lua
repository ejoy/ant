package.path = table.concat({
    "engine/?.lua",
    "engine/?/?.lua",
    "?.lua",
}, ";")

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
require "antpm"

if __ANT_RUNTIME__ then
    --require "runtime.debug"
end
