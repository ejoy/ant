local fs = require "bee.filesystem"

function fs.open(filepath, ...)
    return io.open(filepath:string(), ...)
end
function fs.lines(filepath, ...)
    return io.lines(filepath:string(), ...)
end
function fs.loadfile(filepath, ...)
    return loadfile(filepath:string(), ...)
end
function fs.dofile(filepath)
    return dofile(filepath:string())
end
local path_mt = debug.getmetatable(fs.path())
if not path_mt.localpath then
    function path_mt:localpath()
        return self
    end
end

function fs.app_path(name)
    local platform = require "bee.platform"
    if platform.os == "ios" then
        local ios = require "ios"
        return fs.path(ios.directory(ios.NSDocumentDirectory))
    elseif platform.os == 'windows' then
        return fs.path(os.getenv "LOCALAPPDATA") / name
    elseif platform.os == 'linux' then
        return fs.path(os.getenv "XDG_DATA_HOME" or (os.getenv "HOME" .. "/.local/share")) / name
    elseif platform.os == 'macos' then
        return fs.path(os.getenv "HOME" .. "/Library/Caches") / name
    end
end

return fs
