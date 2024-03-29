local platform = require "bee.platform"

if not __ANT_RUNTIME__ then
    local vfs = require "vfs"
    local app_path = vfs.repopath()
    return {
        internal = app_path ..".app/internal/",
        external = app_path ..".app/external/",
    }
end

if platform.os == "ios" then
    local ios = require "ios"
    return {
        internal = ios.bundle():gsub("/?$", "/"),
        external = ios.directory(ios.NSDocumentDirectory):gsub("/?$", "/"),
    }
elseif platform.os == "android" then
    local android = require "android"
    return {
        internal = android.directory(android.InternalDataPath):gsub("/?$", "/"),
        external = android.directory(android.ExternalDataPath):gsub("/?$", "/"),
    }
else
    local function envpath(name)
        return os.getenv(name):gsub("/?$", "/")
    end
    local app_path = (function ()
        if platform.os == "windows" then
            return envpath "LOCALAPPDATA"
        elseif platform.os == "linux" then
            return envpath "XDG_DATA_HOME" or (envpath "HOME" .. ".local/share/")
        elseif platform.os == "macos" then
            return envpath "HOME" .. "Library/Caches/"
        else
            error "unknown os"
        end
    end)()
    return {
        internal = app_path .."ant/internal/",
        external = app_path .."ant/external/",
    }
end
