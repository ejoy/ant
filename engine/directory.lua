
local platform = require "bee.platform"
local fs = require "bee.filesystem"

local m = {}

if platform.os == "ios" then
    local ios = require "ios"
    local app_path = fs.path(ios.directory(ios.NSDocumentDirectory))
    function m.app_path()
        return app_path
    end
    function m.log_path()
        return app_path
    end
elseif platform.os == 'android' then
    local android = require "android"
    local app_path = fs.path(android.directory(android.ExternalDataPath))
    function m.app_path()
        return app_path
    end
    function m.log_path()
        return app_path
    end
elseif platform.os == 'windows' then
    local app_path = fs.path(os.getenv "LOCALAPPDATA")
    function m.app_path(name)
        return app_path / name
    end
    function m.log_path()
        return fs.current_path()
    end
elseif platform.os == 'linux' then
    local app_path = fs.path(os.getenv "XDG_DATA_HOME" or (os.getenv "HOME" .. "/.local/share"))
    function m.app_path(name)
        return app_path / name
    end
    function m.log_path()
        return fs.current_path()
    end
elseif platform.os == 'macos' then
    local app_path = fs.path(os.getenv "HOME" .. "/Library/Caches")
    function m.app_path(name)
        return app_path / name
    end
    function m.log_path()
        return fs.current_path()
    end
else
    error "unknown os"
end

return m
