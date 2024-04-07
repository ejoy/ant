local platform = require "bee.platform"

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
    local data_path = (function ()
        if platform.os == "windows" then
            --TODO: use SHGetKnownFolderPath
            return envpath "USERPROFILE".. "Saved Games/"
        elseif platform.os == "linux" then
            return envpath "XDG_DATA_HOME" or (envpath "HOME" .. ".local/share/")
        elseif platform.os == "macos" then
            return envpath "HOME" .. "Library/Caches/"
        else
            error "unknown os"
        end
    end)()
    local app_name = (function ()
        local fs = require "bee.filesystem"
        return fs.exe_path():stem():string():match "^([^_]+)"
    end)()
    return {
        internal = data_path .. app_name .. "/internal/",
        external = data_path .. app_name .. "/external/",
    }
end
