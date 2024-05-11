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
    local sys = require "bee.sys"
    local exe_dir = sys.exe_path():parent_path():string():gsub("/?$", "/")
    return {
        internal = exe_dir .. "internal/",
        external = exe_dir .. "external/",
    }
end
