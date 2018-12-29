
local platform = require 'platform'

return function (fs)
    fs.vfs = not __ANT_RUNTIME__
    function fs.open(filepath, ...)
        --TODO vfs?
        return io.open(filepath:string(), ...)
    end
    function fs.lines(filepath, ...)
        --TODO vfs?
        return io.lines(filepath:string(), ...)
    end

    if platform.OS == 'Windows' then
        function fs.mydocs_path()
            return fs.path(os.getenv 'USERPROFILE') / 'Documents'
        end
    else
        function fs.mydocs_path()
            return fs.path(os.getenv 'HOME') / 'Documents'
        end
    end
    return fs
end
