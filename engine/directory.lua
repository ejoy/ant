
local platform = require "bee.platform"
local fs = require "bee.filesystem"

local m = {}

if platform.os == "ios" then
    local ios = require "ios"
    local app_path = fs.path(ios.directory(ios.NSDocumentDirectory))
    function m.app_path()
        return app_path
    end
elseif platform.os == 'android' then
    local android = require "android"
    local app_path = fs.path(android.directory(android.ExternalDataPath))
    function m.app_path()
        return app_path
    end
else
    if __ANT_RUNTIME__ then
        function m.app_path()
            return fs.current_path()
        end
    else
        local vfs = require "vfs"
        local app_path = fs.path(vfs.repopath()) / ".app"
        function m.app_path()
            return app_path
        end
    end
end

return m
