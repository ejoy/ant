debug.setcstacklimit(200)

if __ANT_RUNTIME__ then
    require "runtime.vfs"
    require "runtime.errlog"
else
    local thread = require "thread"
    if thread.id == 0 then
        thread.newchannel "INITTHREAD"
    else
        arg = thread.channel_consume "INITTHREAD"()
    end
    require "editor.init_cpath"
    require "editor.vfs"
    require "editor.log"
end

require "common.init_bgfx"
require "filesystem"
require "packagemanager"

if __ANT_RUNTIME__ then
    require "runtime.debug"
end
