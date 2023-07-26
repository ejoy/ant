local fs = require "bee.filesystem"
local directory = require "directory"

function fs.open(filepath, ...)
    return io.open(filepath:string(), ...)
end
local path_mt = debug.getmetatable(fs.path())
if not path_mt.localpath then
    function path_mt:localpath()
        return self
    end
end

function fs.app_path(name)
    return directory.app_path(name)
end

return fs
