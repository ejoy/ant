local fs = require 'filesystem.cpp'
local platform = require 'platform'

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

function fs.appdata_path()
    if platform.OS == 'Windows' then
        return fs.path(os.getenv "LOCALAPPDATA")
    elseif platform.OS == 'Linux' then
        return fs.path(os.getenv "XDG_DATA_HOME" or (os.getenv "HOME" .. "/.local/share"))
    elseif platform.OS == 'macOS' then
        return fs.path(fs.appdata_path(), os.getenv "HOME" .. "/Library/Caches")
    else
        error "unimplemented"
    end
end

return fs
