
local platform = require "bee.platform"
local fs = require "bee.filesystem"

if platform.os == "ios" then
    local ios = require "ios"
    local app_path = fs.path(ios.directory(ios.NSDocumentDirectory))
    return function ()
        return app_path
    end
elseif platform.os == 'android' then
    local android = require "android"
    local app_path = fs.path(android.directory(android.ExternalDataPath))
    return function ()
        return app_path
    end
elseif __ANT_RUNTIME__ then
    return function ()
        return fs.current_path()
    end
else
    local vfs = require "vfs"
    local app_path = fs.path(vfs.repopath()) / ".app"
    return function ()
        return app_path
    end
end
